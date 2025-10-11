enum UserRole {
  owner,
  admin,
  operator,
  viewer,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
      case UserRole.operator:
        return 'Operator';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case UserRole.owner:
        return 'Full control + manage users';
      case UserRole.admin:
        return 'Full control + invite users';
      case UserRole.operator:
        return 'Control system only';
      case UserRole.viewer:
        return 'Read-only access';
    }
  }

  String get value {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.admin:
        return 'admin';
      case UserRole.operator:
        return 'operator';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'operator':
        return UserRole.operator;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.viewer;
    }
  }

  // Permission checks
  bool get canControl => this == UserRole.owner || this == UserRole.admin || this == UserRole.operator;
  bool get canSchedule => this == UserRole.owner || this == UserRole.admin || this == UserRole.operator;
  bool get canInviteUsers => this == UserRole.owner || this == UserRole.admin;
  bool get canRemoveUsers => this == UserRole.owner || this == UserRole.admin;
  bool get canChangeRoles => this == UserRole.owner;
  bool get canDeleteSystem => this == UserRole.owner;
  bool get canViewData => true; // All roles can view data
  bool get canDeleteLogs => this == UserRole.owner; // Only owner can delete logs
  bool get canViewDeleteButton => this == UserRole.owner || this == UserRole.admin; // Owner and Admin can see delete buttons
}
