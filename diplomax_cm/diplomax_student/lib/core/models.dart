import 'package:flutter/material.dart';
import 'app_colors.dart';

// ─── Document Type ───────────────────────────────────────────────────────────

enum DocumentType {
  diploma,
  transcript,
  certificate,
  attestation,
}

extension DocumentTypeExt on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.diploma:
        return 'Diplôme';
      case DocumentType.transcript:
        return 'Relevé de notes';
      case DocumentType.certificate:
        return 'Certificat';
      case DocumentType.attestation:
        return 'Attestation';
    }
  }

  Color get color {
    switch (this) {
      case DocumentType.diploma:
        return AppColors.diplomaColor;
      case DocumentType.transcript:
        return AppColors.transcriptColor;
      case DocumentType.certificate:
        return AppColors.certifColor;
      case DocumentType.attestation:
        return AppColors.attestColor;
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.diploma:
        return Icons.school_rounded;
      case DocumentType.transcript:
        return Icons.description_rounded;
      case DocumentType.certificate:
        return Icons.verified_rounded;
      case DocumentType.attestation:
        return Icons.assignment_rounded;
    }
  }
}

// ─── Document ────────────────────────────────────────────────────────────────

class AcademicDocument {
  final String id;
  final DocumentType type;
  final String title;
  final String university;
  final String field;
  final String degree;
  final DateTime issueDate;
  final String mention;
  final bool isVerified;
  final String hash;
  final List<CourseGrade>? grades;

  const AcademicDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.university,
    required this.field,
    required this.degree,
    required this.issueDate,
    required this.mention,
    required this.isVerified,
    required this.hash,
    this.grades,
  });

  String get shortId => id.substring(0, 8).toUpperCase();
}

class CourseGrade {
  final String code;
  final String name;
  final double grade;
  final int credits;
  final String semester;

  const CourseGrade({
    required this.code,
    required this.name,
    required this.grade,
    required this.credits,
    required this.semester,
  });

  String get mention {
    if (grade >= 16) return 'Très Bien';
    if (grade >= 14) return 'Bien';
    if (grade >= 12) return 'Assez Bien';
    if (grade >= 10) return 'Passable';
    return 'Insuffisant';
  }
}

// ─── Student ─────────────────────────────────────────────────────────────────

class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String university;
  final String matricule;
  final DateTime dateOfBirth;
  final String photoUrl;

  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.university,
    required this.matricule,
    required this.dateOfBirth,
    required this.photoUrl,
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}';
}

// ─── University ───────────────────────────────────────────────────────────────

class University {
  final String id;
  final String name;
  final String shortName;
  final String city;
  final bool isConnected;

  const University({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    required this.isConnected,
  });
}

// ─── Mock Data ────────────────────────────────────────────────────────────────

class MockData {
  static final student = Student(
    id: 'STU-2024-08491',
    firstName: 'Joëlle Sandrine',
    lastName: 'Bassa',
    email: 'joelle.bassa@ictuniversity.cm',
    phone: '+237 699 123 456',
    university: 'The ICT University',
    matricule: 'ICT/2021/0849',
    dateOfBirth: DateTime(2000, 3, 15),
    photoUrl: '',
  );

  static final List<AcademicDocument> documents = [
    AcademicDocument(
      id: 'doc-a1b2c3d4-e5f6',
      type: DocumentType.diploma,
      title: 'Licence en Génie Logiciel',
      university: 'The ICT University',
      field: 'Génie Logiciel & Cybersécurité',
      degree: 'Licence',
      issueDate: DateTime(2024, 7, 15),
      mention: 'Bien',
      isVerified: true,
      hash:
          'sha256:3a7f9c2e1b4d8f6a0e5c9b3d7f2a8c4e6b1d9f3a7c2e0b8d4f6a1c5e9b7d3f',
      grades: _sampleGrades,
    ),
    AcademicDocument(
      id: 'doc-b2c3d4e5-f6a1',
      type: DocumentType.transcript,
      title: 'Relevé de Notes — Semestres 1 à 6',
      university: 'The ICT University',
      field: 'Génie Logiciel & Cybersécurité',
      degree: 'Licence',
      issueDate: DateTime(2024, 6, 30),
      mention: 'Bien',
      isVerified: true,
      hash:
          'sha256:1c5e9b3d7f2a8c4e6b1d9f3a7c2e0b8d4f6a3a7f9c2e1b4d8f6a0e5c9b3d7f',
      grades: _sampleGrades,
    ),
    AcademicDocument(
      id: 'doc-c3d4e5f6-a1b2',
      type: DocumentType.attestation,
      title: 'Attestation de Réussite — L3',
      university: 'The ICT University',
      field: 'Génie Logiciel',
      degree: 'Licence 3',
      issueDate: DateTime(2024, 5, 10),
      mention: 'Bien',
      isVerified: true,
      hash:
          'sha256:8d4f6a3a7f9c2e1b4d8f6a0e5c9b3d7f2a8c4e6b1d9f3a7c2e0b8d4f6a1c5e',
      grades: null,
    ),
    AcademicDocument(
      id: 'doc-d4e5f6a1-b2c3',
      type: DocumentType.certificate,
      title: 'Certificat de Cybersécurité',
      university: 'The ICT University',
      field: 'Cybersécurité',
      degree: 'Certificat Professionnel',
      issueDate: DateTime(2023, 12, 1),
      mention: 'Très Bien',
      isVerified: true,
      hash:
          'sha256:6b1d9f3a7c2e0b8d4f6a1c5e9b3d7f2a8c4e3a7f9c2e1b4d8f6a0e5c9b3d7f',
      grades: null,
    ),
  ];

  static final List<CourseGrade> _sampleGrades = [
    const CourseGrade(
        code: 'INF301',
        name: 'Algorithmes Avancés',
        grade: 15.5,
        credits: 4,
        semester: 'S5'),
    const CourseGrade(
        code: 'INF302',
        name: 'Développement Mobile',
        grade: 16.0,
        credits: 4,
        semester: 'S5'),
    const CourseGrade(
        code: 'INF303',
        name: 'Sécurité Informatique',
        grade: 14.5,
        credits: 3,
        semester: 'S5'),
    const CourseGrade(
        code: 'INF304',
        name: 'Base de Données',
        grade: 13.0,
        credits: 3,
        semester: 'S5'),
    const CourseGrade(
        code: 'INF305',
        name: 'Réseaux et Protocoles',
        grade: 15.0,
        credits: 3,
        semester: 'S5'),
    const CourseGrade(
        code: 'INF306',
        name: 'Génie Logiciel',
        grade: 17.0,
        credits: 4,
        semester: 'S6'),
    const CourseGrade(
        code: 'INF307',
        name: 'Cryptographie',
        grade: 14.0,
        credits: 3,
        semester: 'S6'),
    const CourseGrade(
        code: 'INF308',
        name: 'Projet de Fin d\'Études',
        grade: 16.5,
        credits: 6,
        semester: 'S6'),
  ];

  static final List<University> universities = [
    const University(
        id: 'ict',
        name: 'The ICT University',
        shortName: 'ICT',
        city: 'Yaoundé',
        isConnected: true),
    const University(
        id: 'uy1',
        name: 'Université de Yaoundé I',
        shortName: 'UY1',
        city: 'Yaoundé',
        isConnected: true),
    const University(
        id: 'uy2',
        name: 'Université de Yaoundé II',
        shortName: 'UY2',
        city: 'Soa',
        isConnected: false),
    const University(
        id: 'ub',
        name: 'Université de Buéa',
        shortName: 'UB',
        city: 'Buéa',
        isConnected: false),
    const University(
        id: 'ud',
        name: 'Université de Douala',
        shortName: 'UD',
        city: 'Douala',
        isConnected: false),
  ];
}
