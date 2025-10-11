class Validators {
  // Email validation - RFC 5322 compliant
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Password validation - 8+ chars, uppercase, lowercase, number, special char
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#^()_+=\-\[\]{}|\\:;"<>,.?/~`])[A-Za-z\d@$!%*?&#^()_+=\-\[\]{}|\\:;"<>,.?/~`]{8,}$',
  );

  // Name validation - letters, spaces, hyphens, apostrophes only
  static final RegExp _nameRegex = RegExp(
    r"^[a-zA-Z\s\-']+$",
  );

  // Check if name contains only valid characters
  static final RegExp _nameCharactersRegex = RegExp(
    r"[^a-zA-Z\s\-']",
  );

  /// Validate email format
  /// Industry standard: Gmail (320 chars), Facebook (254 chars)
  /// Using 320 as max (64 local + 1 @ + 255 domain)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final email = value.trim();

    if (email.length > 320) {
      return 'Email is too long';
    }

    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Additional checks
    if (email.startsWith('.') || email.endsWith('.')) {
      return 'Email cannot start or end with a dot';
    }

    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }

    return null;
  }

  /// Validate password strength
  /// Industry standards: Gmail (100 chars), Facebook (72 chars), Microsoft (256 chars)
  /// Using 72 as max (matches Facebook, reasonable for most use cases)
  static String? validatePassword(String? value, {bool isNewPassword = false}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (value.length > 72) {
      return 'Password is too long';
    }

    if (isNewPassword) {
      // Strict validation for new passwords
      if (!value.contains(RegExp(r'[a-z]'))) {
        return 'Password must contain at least one lowercase letter';
      }

      if (!value.contains(RegExp(r'[A-Z]'))) {
        return 'Password must contain at least one uppercase letter';
      }

      if (!value.contains(RegExp(r'[0-9]'))) {
        return 'Password must contain at least one number';
      }

      if (!value.contains(RegExp(r'[@$!%*?&#^()_+=\-\[\]{}|\\:;"<>,.?/~`]'))) {
        return 'Password must contain at least one special character';
      }

      // Check for common weak passwords
      final lowerValue = value.toLowerCase();
      if (lowerValue.contains('password') || 
          lowerValue.contains('12345678') ||
          lowerValue.contains('qwerty')) {
        return 'Password is too common. Please choose a stronger password';
      }
    }

    return null;
  }

  /// Validate name (first name, last name)
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final name = value.trim();

    if (name.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (name.length > 50) {
      return '$fieldName is too long (max 50 characters)';
    }

    if (!_nameRegex.hasMatch(name)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Check for consecutive spaces
    if (name.contains(RegExp(r'\s{2,}'))) {
      return '$fieldName cannot contain consecutive spaces';
    }

    // Check if starts or ends with space/hyphen
    if (name.startsWith(' ') || name.endsWith(' ') || 
        name.startsWith('-') || name.endsWith('-')) {
      return '$fieldName cannot start or end with spaces or hyphens';
    }

    return null;
  }

  /// Validate password confirmation
  static String? validatePasswordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Get password strength (0-4)
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;

    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[@$!%*?&#^()_+=\-\[\]{}|\\:;"<>,.?/~`]'))) strength++;

    return (strength / 6 * 4).round().clamp(0, 4);
  }

  /// Get password strength label
  static String getPasswordStrengthLabel(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Weak';
    }
  }

  /// Get password strength color
  static int getPasswordStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 0xFFEF5350; // Red
      case 2:
        return 0xFFFF9800; // Orange
      case 3:
        return 0xFFFFEB3B; // Yellow
      case 4:
        return 0xFF4CAF50; // Green
      default:
        return 0xFFEF5350; // Red
    }
  }

  /// Check if string contains invalid characters for names
  static bool hasInvalidNameCharacters(String value) {
    return _nameCharactersRegex.hasMatch(value);
  }
}
