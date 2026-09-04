<?php

final class EmailService {
    public static function send(string $to, string $subject, string $htmlBody): bool {
        try {
            // Resend first, over HTTPS. The SMTP paths below are kept as a
            // fallback, but they are no longer the way out of this box: Hetzner
            // blocks outbound 25 and 465 by default, which is why nothing sent
            // between the July migration and 2026-09-04 ever left — and why
            // nobody noticed, since a failed send only ever returned false.
            $resendKey = getenv('RESEND_API_KEY') ?: '';
            if ($resendKey !== '') {
                return self::sendViaResend($to, $subject, $htmlBody, $resendKey);
            }

            $smtpHost = getenv('SMTP_HOST');
            if (empty($smtpHost)) {
                self::recordFailure($to, 'neither RESEND_API_KEY nor SMTP_HOST is configured');
                return false;
            }

            $smtpPort = (int) (getenv('SMTP_PORT') ?: 587);
            $smtpUser = getenv('SMTP_USER') ?: '';
            $smtpPass = getenv('SMTP_PASS') ?: '';
            $smtpFrom = getenv('SMTP_FROM') ?: 'noreply@permedjat.com';
            $smtpSecure = getenv('SMTP_SECURE') ?: 'tls';

            if (class_exists('PHPMailer\PHPMailer\PHPMailer')) {
                return self::sendViaPhpMailer($to, $subject, $htmlBody, $smtpHost, $smtpPort, $smtpUser, $smtpPass, $smtpFrom, $smtpSecure);
            }

            // No PHPMailer installed: use a built-in authenticated SMTP client
            // (needed so mail is signed/authenticated by the SMTP provider).
            if (!empty($smtpUser) && !empty($smtpPass)) {
                return self::sendViaSmtpSocket($to, $subject, $htmlBody, $smtpHost, $smtpPort, $smtpUser, $smtpPass, $smtpFrom, $smtpSecure);
            }

            return self::sendViaMail($to, $subject, $htmlBody, $smtpFrom);
        } catch (Exception $e) {
            self::recordFailure($to, $e->getMessage());
            return false;
        }
    }

    /**
     * Posts the message to Resend over HTTPS. No SMTP port is involved, so no
     * host's outbound mail policy can silence it.
     */
    private static function sendViaResend(string $to, string $subject, string $htmlBody, string $apiKey): bool {
        $from = getenv('MAIL_FROM') ?: 'Permedjat <noreply@mail.permedjat.com>';
        $payload = [
            'from'    => $from,
            'to'      => [$to],
            'subject' => $subject,
            'html'    => $htmlBody,
        ];
        // Replies belong in a mailbox a human reads, not in the sending domain.
        $replyTo = getenv('MAIL_REPLY_TO') ?: '';
        if ($replyTo !== '') {
            $payload['reply_to'] = $replyTo;
        }

        $ch = curl_init('https://api.resend.com/emails');
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $apiKey,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS     => json_encode($payload, JSON_UNESCAPED_UNICODE),
        ]);
        $body = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err  = curl_error($ch);
        curl_close($ch);

        if ($body === false || $code < 200 || $code >= 300) {
            // The reason matters: a 422 is a bad address, a 403 is a revoked
            // key, a 429 is the daily quota. Each needs a different response,
            // so record which one it was rather than a bare failure.
            self::recordFailure($to, sprintf(
                'resend http %d%s %s',
                $code,
                $err !== '' ? " curl=$err" : '',
                is_string($body) ? substr($body, 0, 300) : ''
            ));
            return false;
        }
        return true;
    }

    /**
     * Every failed send lands here, in the log and in a counter file the node
     * metrics script exports to Prometheus. Silence is what let the mail
     * outage run from July to September unnoticed; this is the fix for that,
     * and it matters more than which provider is in front of it.
     */
    private static function recordFailure(string $to, string $reason): void {
        $masked = preg_replace('/^(.).*(@.*)$/u', '$1***$2', $to);
        error_log(sprintf('EmailService: send to %s failed — %s', $masked, $reason));

        $path = getenv('MAIL_FAILURE_LOG') ?: '/var/log/permedjat-mail-failures.log';
        $line = sprintf("%s\t%s\t%s\n", gmdate('c'), $masked, str_replace(["\n", "\t"], ' ', $reason));
        @file_put_contents($path, $line, FILE_APPEND | LOCK_EX);
    }

    private static function sendViaPhpMailer(string $to, string $subject, string $htmlBody, string $host, int $port, string $user, string $pass, string $from, string $secure): bool {
        $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
        $mail->CharSet = 'UTF-8';
        $mail->setLanguage('ar');

        $mail->isSMTP();
        $mail->Host = $host;
        $mail->Port = $port;
        $mail->SMTPAuth = !empty($user);
        $mail->Username = $user;
        $mail->Password = $pass;
        $mail->SMTPSecure = $secure === 'ssl' ? \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_SMTPS : \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;

        $mail->setFrom($from, 'Permedjat');
        $mail->addAddress($to);
        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = $htmlBody;

        return $mail->send();
    }

    /**
     * Minimal dependency-free authenticated SMTP client (AUTH LOGIN).
     * Supports implicit SSL (port 465, secure="ssl") and STARTTLS (port 587).
     */
    private static function sendViaSmtpSocket(string $to, string $subject, string $htmlBody, string $host, int $port, string $user, string $pass, string $from, string $secure): bool {
        $fromDomain = substr(strrchr($from, '@') ?: '@localhost', 1) ?: 'localhost';
        $transport = $secure === 'ssl' ? "ssl://{$host}" : $host;

        $errno = 0;
        $errstr = '';
        // Short connect timeout so an unreachable/slow relay fast-fails instead
        // of hanging a worker (this send already runs off the request path).
        $fp = @fsockopen($transport, $port, $errno, $errstr, 8);
        if (!$fp) {
            error_log("EmailService SMTP connect failed: {$errstr} ({$errno})");
            return false;
        }
        stream_set_timeout($fp, 15);

        $read = static function () use ($fp): string {
            $data = '';
            while (($line = fgets($fp, 515)) !== false) {
                $data .= $line;
                // Last line of a reply has a space at position 3 (e.g. "250 OK").
                if (strlen($line) < 4 || $line[3] === ' ') {
                    break;
                }
            }
            return $data;
        };
        $write = static function (string $cmd) use ($fp): void {
            fwrite($fp, $cmd . "\r\n");
        };
        $expect = static function (string $resp, string $code): bool {
            return strncmp($resp, $code, strlen($code)) === 0;
        };

        try {
            if (!$expect($read(), '220')) {
                fclose($fp);
                return false;
            }

            $write('EHLO ' . $fromDomain);
            $read();

            if ($secure !== 'ssl') {
                $write('STARTTLS');
                if (!$expect($read(), '220')) {
                    fclose($fp);
                    return false;
                }
                if (!stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    fclose($fp);
                    return false;
                }
                $write('EHLO ' . $fromDomain);
                $read();
            }

            $write('AUTH LOGIN');
            $read();
            $write(base64_encode($user));
            $read();
            $write(base64_encode($pass));
            if (!$expect($read(), '235')) {
                error_log('EmailService SMTP auth failed');
                $write('QUIT');
                fclose($fp);
                return false;
            }

            $write("MAIL FROM:<{$from}>");
            if (!$expect($read(), '250')) {
                fclose($fp);
                return false;
            }
            $write("RCPT TO:<{$to}>");
            $rcpt = $read();
            if (!$expect($rcpt, '250') && !$expect($rcpt, '251')) {
                fclose($fp);
                return false;
            }

            $write('DATA');
            if (!$expect($read(), '354')) {
                fclose($fp);
                return false;
            }

            $headers = 'From: Permedjat <' . $from . '>' . "\r\n"
                . 'To: <' . $to . '>' . "\r\n"
                . 'Subject: =?UTF-8?B?' . base64_encode($subject) . '?=' . "\r\n"
                . 'MIME-Version: 1.0' . "\r\n"
                . 'Content-Type: text/html; charset=UTF-8' . "\r\n"
                . 'Content-Transfer-Encoding: base64' . "\r\n";

            // Base64-encode the body in 76-char CRLF lines. This keeps every line
            // well under the SMTP 1000-octet limit and never splits a multi-byte
            // UTF-8 character (which would corrupt Arabic text).
            $body = rtrim(chunk_split(base64_encode($htmlBody), 76, "\r\n"));

            $write($headers . "\r\n" . $body . "\r\n.");
            $ok = $expect($read(), '250');

            $write('QUIT');
            fclose($fp);
            return $ok;
        } catch (\Throwable $e) {
            error_log('EmailService SMTP error: ' . $e->getMessage());
            if (is_resource($fp)) {
                fclose($fp);
            }
            return false;
        }
    }

    private static function sendViaMail(string $to, string $subject, string $htmlBody, string $from): bool {
        $headers = implode("\r\n", [
            'From: Permedjat <' . $from . '>',
            'Content-Type: text/html; charset=UTF-8',
            'MIME-Version: 1.0',
        ]);

        return mail($to, '=?UTF-8?B?' . base64_encode($subject) . '?=', $htmlBody, $headers);
    }
}
