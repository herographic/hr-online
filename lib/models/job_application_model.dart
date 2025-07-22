// lib/models/job_application_model.dart
// *** หมายเหตุ: ไฟล์นี้จะถูกใช้ร่วมกันทั้ง 2 โปรเจกต์ ***

import 'package:cloud_firestore/cloud_firestore.dart';

class JobApplication {
  final String id;
  final Timestamp appliedAt;
  String status;

  String? adminNotes;
  Timestamp? interviewDate;

  String? photoUrl;

  String position1;
  String salary1;
  String position2;
  String salary2;
  String employmentType;

  String title;
  String firstName;
  String lastName;
  String nickname;
  DateTime? birthDate;
  int age;
  String idCardNumber;
  DateTime? idCardExpiry;
  String address;
  String phoneNumber;
  String secondaryPhoneNumber;
  String email;
  String livingSituation;
  String race;
  String nationality;
  String religion;
  double height;
  double weight;
  String maritalStatus;
  String gender;

  String militaryStatus;
  String graduationStatus;

  String fatherName;
  int fatherAge;
  String fatherOccupation;
  String motherName;
  int motherAge;
  String motherOccupation;
  String spouseName;
  String spouseWorkplace;
  String spousePosition;
  int childrenCount;
  List<Map<String, String>> siblings;

  List<Map<String, String>> educationHistory;
  List<Map<String, String>> internships;

  List<Map<String, dynamic>> workHistory;

  Map<String, Map<String, String>> languageSkills;

  int thaiTypingSpeed;
  int engTypingSpeed;
  bool? canTouchType;
  bool hasMsOfficeSkill;
  bool canUsePrinterCopier;
  String computerProficiency;
  String computerSkillsDetails;
  bool canDrive;
  String drivingLicenseNo;
  String officeMachineSkills;
  String hobbies;
  String favoriteSport;
  String specialKnowledge;

  bool canProgram;
  List<String> programmingLanguages;
  bool knowsChatAi;
  List<String> chatAiUsed;

  String motivation;

  String canWorkUpcountry;
  String emergencyContactName;
  String emergencyContactRelation;
  String emergencyContactAddress;
  String emergencyContactPhone;
  String jobSource;
  bool hadSeriousIllness;
  String illnessDetails;
  bool appliedBefore;
  String appliedBeforeDate;
  String relativesInCompany;
  List<Map<String, String>> references;
  bool consent;

  String? idCardCopyUrl;
  String? houseRegCopyUrl;
  String? portfolioUrl;
  String? employmentCertificateUrl;
  List<String> otherDocumentsUrls;
  
  String? signatureUrl;


  JobApplication({
    required this.id,
    required this.appliedAt,
    this.status = 'pending',
    this.adminNotes,
    this.interviewDate,
    this.photoUrl,
    this.position1 = '',
    this.salary1 = '',
    this.position2 = '',
    this.salary2 = '',
    this.employmentType = 'Full-time',
    this.title = 'นาย',
    this.firstName = '',
    this.lastName = '',
    this.nickname = '', 
    this.birthDate,
    this.age = 0,
    this.idCardNumber = '',
    this.idCardExpiry,
    this.address = '',
    this.phoneNumber = '',
    this.secondaryPhoneNumber = '',
    this.email = '',
    this.livingSituation = '',
    this.race = '',
    this.nationality = '',
    this.religion = '',
    this.height = 0.0,
    this.weight = 0.0,
    this.maritalStatus = '',
    this.gender = '',
    this.militaryStatus = 'ยังไม่ผ่านการเกณฑ์ทหาร', 
    this.graduationStatus = 'ยังไม่รับปริญญาตรี',
    this.fatherName = '',
    this.fatherAge = 0,
    this.fatherOccupation = '',
    this.motherName = '',
    this.motherAge = 0,
    this.motherOccupation = '',
    this.spouseName = '',
    this.spouseWorkplace = '',
    this.spousePosition = '',
    this.childrenCount = 0,
    this.siblings = const [],
    this.educationHistory = const [],
    this.internships = const [], 
    this.workHistory = const [],
    this.languageSkills = const {},
    this.thaiTypingSpeed = 0,
    this.engTypingSpeed = 0,
    this.canTouchType,
    this.hasMsOfficeSkill = false,
    this.canUsePrinterCopier = false,
    this.computerProficiency = 'ทั่วไป',
    this.computerSkillsDetails = '',
    this.canDrive = false,
    this.drivingLicenseNo = '',
    this.officeMachineSkills = '',
    this.hobbies = '',
    this.favoriteSport = '',
    this.specialKnowledge = '',
    this.canProgram = false,
    this.programmingLanguages = const [],
    this.knowsChatAi = false,
    this.chatAiUsed = const [],
    this.motivation = '', 
    this.canWorkUpcountry = '',
    this.emergencyContactName = '',
    this.emergencyContactRelation = '',
    this.emergencyContactAddress = '',
    this.emergencyContactPhone = '',
    this.jobSource = '',
    this.hadSeriousIllness = false,
    this.illnessDetails = '',
    this.appliedBefore = false,
    this.appliedBeforeDate = '',
    this.relativesInCompany = '',
    this.references = const [],
    this.consent = false,
    this.idCardCopyUrl, 
    this.houseRegCopyUrl, 
    this.portfolioUrl, 
    this.employmentCertificateUrl, 
    this.otherDocumentsUrls = const [], 
    this.signatureUrl, 
  });

  Map<String, dynamic> toFirestore() {
    return {
      'appliedAt': appliedAt,
      'status': status,
      'adminNotes': adminNotes,
      'interviewDate': interviewDate,
      'photoUrl': photoUrl,
      'position1': position1,
      'salary1': salary1,
      'position2': position2,
      'salary2': salary2,
      'employmentType': employmentType,
      'title': title,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'age': age,
      'idCardNumber': idCardNumber,
      'idCardExpiry': idCardExpiry != null ? Timestamp.fromDate(idCardExpiry!) : null,
      'address': address,
      'phoneNumber': phoneNumber,
      'secondaryPhoneNumber': secondaryPhoneNumber,
      'email': email,
      'livingSituation': livingSituation,
      'race': race,
      'nationality': nationality,
      'religion': religion,
      'height': height,
      'weight': weight,
      'maritalStatus': maritalStatus,
      'gender': gender,
      'militaryStatus': militaryStatus,
      'graduationStatus': graduationStatus,
      'fatherName': fatherName,
      'fatherAge': fatherAge,
      'fatherOccupation': fatherOccupation,
      'motherName': motherName,
      'motherAge': motherAge,
      'motherOccupation': motherOccupation,
      'spouseName': spouseName,
      'spouseWorkplace': spouseWorkplace,
      'spousePosition': spousePosition,
      'childrenCount': childrenCount,
      'siblings': siblings,
      'educationHistory': educationHistory,
      'internships': internships,
      'workHistory': workHistory,
      'languageSkills': languageSkills,
      'thaiTypingSpeed': thaiTypingSpeed,
      'engTypingSpeed': engTypingSpeed,
      'canTouchType': canTouchType,
      'hasMsOfficeSkill': hasMsOfficeSkill,
      'canUsePrinterCopier': canUsePrinterCopier,
      'computerProficiency': computerProficiency,
      'computerSkillsDetails': computerSkillsDetails,
      'canDrive': canDrive,
      'drivingLicenseNo': drivingLicenseNo,
      'officeMachineSkills': officeMachineSkills,
      'hobbies': hobbies,
      'favoriteSport': favoriteSport,
      'specialKnowledge': specialKnowledge,
      'canProgram': canProgram,
      'programmingLanguages': programmingLanguages,
      'knowsChatAi': knowsChatAi,
      'chatAiUsed': chatAiUsed,
      'motivation': motivation,
      'canWorkUpcountry': canWorkUpcountry,
      'emergencyContactName': emergencyContactName,
      'emergencyContactRelation': emergencyContactRelation,
      'emergencyContactAddress': emergencyContactAddress,
      'emergencyContactPhone': emergencyContactPhone,
      'jobSource': jobSource,
      'hadSeriousIllness': hadSeriousIllness,
      'illnessDetails': illnessDetails,
      'appliedBefore': appliedBefore,
      'appliedBeforeDate': appliedBeforeDate,
      'relativesInCompany': relativesInCompany,
      'references': references,
      'consent': consent,
      'idCardCopyUrl': idCardCopyUrl,
      'houseRegCopyUrl': houseRegCopyUrl,
      'portfolioUrl': portfolioUrl,
      'employmentCertificateUrl': employmentCertificateUrl,
      'otherDocumentsUrls': otherDocumentsUrls,
      'signatureUrl': signatureUrl,
    };
  }

  factory JobApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // --- [START] เพิ่ม Helper Function สำหรับแปลงข้อมูลอย่างปลอดภัย ---
    List<String> _parseStringList(dynamic value) {
      if (value is List) {
        return List<String>.from(value);
      }
      if (value is String && value.isNotEmpty) {
        // จัดการข้อมูลเก่าที่เป็น String โดยถือว่าเป็น List ที่มี 1 item
        return [value];
      }
      return [];
    }
    // --- [END] เพิ่ม Helper Function ---
    
    List<Map<String, String>> _mapListString(dynamic list) {
      if (list is List) {
        return List<Map<String, String>>.from(
          list.map((item) => Map<String, String>.from(item))
        );
      }
      return [];
    }
    
    List<Map<String, dynamic>> _mapListDynamic(dynamic list) {
      if (list is List) {
        return List<Map<String, dynamic>>.from(
          list.map((item) => Map<String, dynamic>.from(item))
        );
      }
      return [];
    }

    Map<String, Map<String, String>> _mapLanguage(dynamic map) {
       if (map is Map) {
        return Map<String, Map<String, String>>.from(
          map.map((key, value) => MapEntry(
            key.toString(),
            Map<String, String>.from(value),
          )),
        );
      }
      return {};
    }

    return JobApplication(
      id: doc.id,
      appliedAt: data['appliedAt'] ?? Timestamp.now(),
      status: data['status'] ?? 'pending',
      adminNotes: data['adminNotes'],
      interviewDate: data['interviewDate'],
      photoUrl: data['photoUrl'],
      position1: data['position1'] ?? '',
      salary1: data['salary1'] ?? '',
      position2: data['position2'] ?? '',
      salary2: data['salary2'] ?? '',
      employmentType: data['employmentType'] ?? 'Full-time',
      title: data['title'] ?? 'นาย',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      nickname: data['nickname'] ?? '',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      age: data['age'] ?? 0,
      idCardNumber: data['idCardNumber'] ?? '',
      idCardExpiry: (data['idCardExpiry'] as Timestamp?)?.toDate(),
      address: data['address'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      secondaryPhoneNumber: data['secondaryPhoneNumber'] ?? '',
      email: data['email'] ?? '',
      livingSituation: data['livingSituation'] ?? '',
      race: data['race'] ?? '',
      nationality: data['nationality'] ?? '',
      religion: data['religion'] ?? '',
      height: (data['height'] as num?)?.toDouble() ?? 0.0,
      weight: (data['weight'] as num?)?.toDouble() ?? 0.0,
      maritalStatus: data['maritalStatus'] ?? '',
      gender: data['gender'] ?? '',
      militaryStatus: data['militaryStatus'] ?? 'ยังไม่ผ่านการเกณฑ์ทหาร',
      graduationStatus: data['graduationStatus'] ?? 'ยังไม่รับปริญญาตรี',
      fatherName: data['fatherName'] ?? '',
      fatherAge: data['fatherAge'] ?? 0,
      fatherOccupation: data['fatherOccupation'] ?? '',
      motherName: data['motherName'] ?? '',
      motherAge: data['motherAge'] ?? 0,
      motherOccupation: data['motherOccupation'] ?? '',
      spouseName: data['spouseName'] ?? '',
      spouseWorkplace: data['spouseWorkplace'] ?? '',
      spousePosition: data['spousePosition'] ?? '',
      childrenCount: data['childrenCount'] ?? 0,
      siblings: _mapListString(data['siblings']),
      educationHistory: _mapListString(data['educationHistory']),
      internships: _mapListString(data['internships']),
      workHistory: _mapListDynamic(data['workHistory']),
      languageSkills: _mapLanguage(data['languageSkills']),
      thaiTypingSpeed: data['thaiTypingSpeed'] ?? 0,
      engTypingSpeed: data['engTypingSpeed'] ?? 0,
      canTouchType: data['canTouchType'],
      hasMsOfficeSkill: data['hasMsOfficeSkill'] ?? false,
      canUsePrinterCopier: data['canUsePrinterCopier'] ?? false,
      computerProficiency: data['computerProficiency'] ?? 'ทั่วไป',
      computerSkillsDetails: data['computerSkillsDetails'] ?? '',
      canDrive: data['canDrive'] ?? false,
      drivingLicenseNo: data['drivingLicenseNo'] ?? '',
      officeMachineSkills: data['officeMachineSkills'] ?? '',
      hobbies: data['hobbies'] ?? '',
      favoriteSport: data['favoriteSport'] ?? '',
      specialKnowledge: data['specialKnowledge'] ?? '',
      canProgram: data['canProgram'] ?? false,
      // --- [START] ใช้ Helper Function ที่สร้างขึ้น ---
      programmingLanguages: _parseStringList(data['programmingLanguages']),
      knowsChatAi: data['knowsChatAi'] ?? false,
      chatAiUsed: _parseStringList(data['chatAiUsed']),
      // --- [END] ใช้ Helper Function ---
      motivation: data['motivation'] ?? '',
      canWorkUpcountry: data['canWorkUpcountry'] ?? '',
      emergencyContactName: data['emergencyContactName'] ?? '',
      emergencyContactRelation: data['emergencyContactRelation'] ?? '',
      emergencyContactAddress: data['emergencyContactAddress'] ?? '',
      emergencyContactPhone: data['emergencyContactPhone'] ?? '',
      jobSource: data['jobSource'] ?? '',
      hadSeriousIllness: data['hadSeriousIllness'] ?? false,
      illnessDetails: data['illnessDetails'] ?? '',
      appliedBefore: data['appliedBefore'] ?? false,
      appliedBeforeDate: data['appliedBeforeDate'] ?? '',
      relativesInCompany: data['relativesInCompany'] ?? '',
      references: _mapListString(data['references']),
      consent: data['consent'] ?? false,
      idCardCopyUrl: data['idCardCopyUrl'],
      houseRegCopyUrl: data['houseRegCopyUrl'],
      portfolioUrl: data['portfolioUrl'],
      employmentCertificateUrl: data['employmentCertificateUrl'],
      otherDocumentsUrls: List<String>.from(data['otherDocumentsUrls'] ?? []),
      signatureUrl: data['signatureUrl'],
    );
  }
}
