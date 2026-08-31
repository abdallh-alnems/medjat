<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Domain;

/**
 * Sends a push notification to an employee's registered devices.
 *
 * Behind an interface so every endpoint that notifies somebody stays testable
 * without Firebase credentials, and so a failure to deliver a push can never
 * fail the action that triggered it.
 *
 * @phpstan-type PushData array<string, string>
 */
interface PushSender
{
    /**
     * @param  array<string, string>  $data  Payload the app routes on. Strings
     *                                       only: FCM silently drops anything
     *                                       else from the data block.
     * @return bool Whether it was accepted for delivery.
     */
    public function toEmployee(int $employeeId, string $title, string $body, array $data = []): bool;

    /**
     * @param  array<string, string>  $data
     */
    public function toAdmin(int $adminId, string $title, string $body, array $data = []): bool;

    /**
     * A silent, data-only message to everybody subscribed to a topic.
     *
     * Used for signals the app acts on rather than shows — switching an app
     * into maintenance, for instance, which otherwise waits on Remote Config's
     * realtime stream and only while the app is foregrounded.
     *
     * @param  array<string, string>  $data
     */
    public function toTopic(string $topic, array $data): bool;
}
