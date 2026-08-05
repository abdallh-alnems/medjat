mc<?php

return [
    'login_success' => 'Login successful',
    'logout_success' => 'Logged out successfully',
    'check_in_success' => 'Check-in successful',
    'check_out_success' => 'Check-out successful',
    'already_checked_in' => 'Already checked in today',
    'gps_out_of_range' => 'You are outside your branch area. Move closer and try again.',
    'invalid_qr' => 'Invalid QR code for this branch',
    'employee_not_found' => 'Employee not found',
    'branch_not_found' => 'Branch not found',
    'tenant_not_found' => 'Company not found',
    'tenant_suspended' => 'Company account is suspended',
    'permission_denied' => 'Permission denied for this action',
    'payroll_generated' => 'Payroll generated successfully',
    'leave_applied' => 'Leave request submitted',
    'leave_approved' => 'Leave approved',
    'leave_rejected' => 'Leave rejected',
    'absence_converted' => 'Absence converted to leave',
    'warning_issued' => 'Warning issued',
    'document_uploaded' => 'Document uploaded successfully',
    'rules_updated' => 'Rules updated successfully',
    'profile_updated' => 'Profile updated',
    'offline_synced' => 'Offline data synced',
    'force_update' => 'Please update the app to continue',

    // Face check-in (face_selfie)
    'face_not_enrolled' => 'Your face is not enrolled yet — please enrol it first',
    'face_already_enrolled' => 'Your face is already enrolled; contact HR to re-enrol',
    'face_reenroll_required' => 'Face re-enrollment is required after the system update',
    'face_challenge_expired' => 'This verification attempt expired, please try again',
    'face_liveness_failed' => 'We could not confirm you are in front of the camera, try again',
    'face_not_recognized' => 'We did not recognise your face, try again in better light',
    'face_capture_failed' => 'Face capture failed, please try again',
    'face_quality_too_low' => 'Image quality is too low — try better light and hold still',
    'face_required_for_checkout' => 'Check-out requires face verification',

    // WiFi check-in (wifi_gps)
    'wifi_not_connected' => 'You must be connected to the branch WiFi to check in',
    'wifi_wrong_network' => 'You are connected to a network that is not approved for this branch',
    'wifi_capture_outside_branch' => 'You must be inside the branch area to capture its network',

    // Device integrity
    'mock_location_rejected' => 'Your device is reporting a fake location. Turn off any location-spoofing app and try again.',
    'local_biometric_required' => 'Your company requires you to confirm your identity with your device fingerprint or face unlock before recording attendance.',

    // Generic
    'rate_limited' => 'Too many attempts. Please wait a moment and try again.',
    'missing_fields' => 'Please fill in all the required fields.',
    'account_suspended' => 'This account has been suspended. Contact your HR administrator.',
    'generic_error' => 'Something went wrong. Please try again.',

    // Browser attendance
    'web_attendance_not_allowed' => 'Your company does not allow recording attendance from a browser. Please use the Medjat app.',
    'web_pin_reject_length' => 'The PIN must be exactly 6 digits.',
    'web_pin_reject_repeated' => 'A PIN of one repeated digit is too easy to guess. Choose another.',
    'web_pin_reject_sequence' => 'Consecutive digits like 123456 are the first thing an attacker tries. Choose another.',
    'web_pin_reject_pattern' => 'A repeating pattern like 121212 is too easy to guess. Choose another.',
    'web_pin_reject_common' => 'This is one of the most commonly used PINs. Choose another.',
    'web_pin_reject_phone' => 'Do not use digits from your phone number — it is how you sign in, so anyone who knows it could guess your PIN.',
    'web_pin_invalid_format' => 'The PIN must be 6 digits and must not be a simple sequence or a repeated digit.',
    'web_invalid_credentials' => 'The phone number or PIN is incorrect.',
    'web_pin_locked' => 'Too many incorrect attempts. Ask your HR administrator to reset your PIN.',
    'web_not_activated' => 'You have not set a PIN yet. Use the activation code from your employer to set one.',
    'web_already_activated' => 'You already have a PIN. Sign in with it, or ask your administrator to reset it.',
    'web_photo_required' => 'Your company requires a photo when recording attendance from a browser. Allow camera access and try again.',
    'web_photo_invalid' => 'We could not read that photo. Try again.',
    'web_pin_reset_done' => 'The PIN has been reset. Give the employee the new activation code.',

    // Branch kiosk — shown on a tablet bolted to a wall, read by a worker in a
    // queue from one to three metres away. No error codes, no jargon: every
    // string says what to do next.
    'kiosk_token_invalid' => 'This device is no longer linked to the branch. Ask your administrator to pair it again.',
    'kiosk_update_required' => 'To the administrator: this tablet needs a kiosk app update before it can record attendance.',
    'kiosk_maintenance' => 'The system is briefly under maintenance. Attendance will resume by itself.',
    'kiosk_offline' => 'There is no internet connection, so attendance cannot be recorded right now. Ask your supervisor to record it manually.',

    // Identification outcomes
    'kiosk_no_match' => 'We did not recognise you. Try again, or use your personal code.',
    'kiosk_ambiguous' => 'The image was not clear enough to be sure who you are. Step a little closer and try again, or use your personal code.',
    'kiosk_not_enrolled' => 'Your face is not enrolled yet. Ask your supervisor to enrol it.',
    'kiosk_out_of_branch' => 'You are not assigned to this branch.',
    'kiosk_wrong_method' => 'Your attendance method is not the kiosk. Use the Medjat app.',
    'kiosk_liveness_failed' => 'Look straight at the camera and follow the prompt.',
    'kiosk_spoofing_suspected' => 'We could not confirm a live person in front of the camera. Try again.',
    'kiosk_too_soon' => 'We already recorded you a moment ago.',
    'kiosk_out_of_range' => 'This tablet is outside the branch area. Tell your administrator.',
    'kiosk_quality_low' => 'The image is not clear. Improve the lighting and try again.',

    // Personal code
    'kiosk_code_invalid' => 'That code is not correct.',
    'kiosk_code_disabled' => 'The personal code is not enabled at this branch.',
    'kiosk_code_throttled' => 'Too many incorrect attempts. Wait a moment and try again.',

    // Pairing and the administration area
    'kiosk_pair_code_spent' => 'That code is invalid or has already been used. Ask for a new one.',
    'kiosk_pair_branch_disabled' => 'The kiosk is not enabled for this branch. Turn it on in the branch settings first.',
    'kiosk_admin_session_expired' => 'The administration session has ended. Enter a new access code.',
    'kiosk_enroll_replaced' => 'This employee is already enrolled. Confirm replacement to record a new face.',
    'kiosk_enroll_done' => 'Enrolled.',
];
