<?php

final class EmailService {
    public static function send(string $to, string $subject, string $htmlBody): bool {
        try {
            $smtpHost = getenv('SMTP_HOST');
            if (empty($smtpHost)) {
                error_log('EmailService: SMTP_HOST not configured, skipping email');
                return false;
            }

            $smtpPort = (int) (getenv('SMTP_PORT') ?: 587);
            $smtpUser = getenv('SMTP_USER') ?: '';
            $smtpPass = getenv('SMTP_PASS') ?: '';
            $smtpFrom = getenv('SMTP_FROM') ?: 'noreply@medjat.com';
            $smtpSecure = getenv('SMTP_SECURE') ?: 'tls';

            if (class_exists('PHPMailer\PHPMailer\PHPMailer')) {
                return self::sendViaPhpMailer($to, $subject, $htmlBody, $smtpHost, $smtpPort, $smtpUser, $smtpPass, $smtpFrom, $smtpSecure);
            }

            return self::sendViaMail($to, $subject, $htmlBody, $smtpFrom);
        } catch (Exception $e) {
            error_log('EmailService error: ' . $e->getMessage());
            return false;
        }
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

        $mail->setFrom($from, 'Medjat');
        $mail->addAddress($to);
        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = $htmlBody;

        return $mail->send();
    }

    private static function sendViaMail(string $to, string $subject, string $htmlBody, string $from): bool {
        $headers = implode("\r\n", [
            'From: Medjat <' . $from . '>',
            'Content-Type: text/html; charset=UTF-8',
            'MIME-Version: 1.0',
        ]);

        return mail($to, '=?UTF-8?B?' . base64_encode($subject) . '?=', $htmlBody, $headers);
    }
}
