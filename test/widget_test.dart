// اختبار أساسي: التأكد من أن نماذج الحالات (enums) في المشروع تُترجم بشكل
// صحيح من/إلى القيم المخزّنة في قاعدة بيانات Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:rwad_admin_app/models/profile.dart';
import 'package:rwad_admin_app/models/consultation.dart';
import 'package:rwad_admin_app/models/appointment.dart';
import 'package:rwad_admin_app/models/support_ticket.dart';

void main() {
  group('Profile role mapping', () {
    test('roleFromString يطابق قيم قاعدة البيانات', () {
      expect(roleFromString('super_admin'), StaffRole.superAdmin);
      expect(roleFromString('admin'), StaffRole.admin);
      expect(roleFromString('client'), StaffRole.client);
      expect(roleFromString(null), StaffRole.client);
    });

    test('isStaff صحيح فقط للموظفين والمشرفين', () {
      final staff = Profile(id: '1', name: 'a', role: StaffRole.admin, createdAt: DateTime.now());
      final client = Profile(id: '2', name: 'b', role: StaffRole.client, createdAt: DateTime.now());
      expect(staff.isStaff, isTrue);
      expect(client.isStaff, isFalse);
    });

    test('roleToDb round-trip مع roleFromString', () {
      for (final r in StaffRole.values) {
        expect(roleFromString(roleToDb(r)), r);
      }
    });
  });

  group('Consultation status mapping', () {
    test('round-trip بين enum وقيمة القاعدة', () {
      for (final s in ConsultationStatus.values) {
        expect(consultationStatusFromString(consultationStatusToDb(s)), s);
      }
    });
  });

  group('Appointment mapping', () {
    test('fromMap يقرأ الحقول الأساسية بشكل صحيح', () {
      final appt = Appointment.fromMap({
        'id': '10',
        'client_name': 'محمد',
        'title': 'استشارة عقارية',
        'scheduled_at': '2026-01-01T10:00:00Z',
        'duration': 45,
        'type': 'video',
        'status': 'upcoming',
        'meeting_link': 'rwad-peer-abc123',
      });
      expect(appt.clientName, 'محمد');
      expect(appt.type, AppointmentType.video);
      expect(appt.status, AppointmentStatus.upcoming);
      expect(appt.isCallable, isTrue);
    });

    test('isCallable خاطئ للمواعيد الحضورية', () {
      final appt = Appointment.fromMap({
        'id': '11',
        'client_name': 'سالم',
        'title': 'اجتماع',
        'scheduled_at': '2026-01-01T10:00:00Z',
        'type': 'in_person',
        'status': 'upcoming',
      });
      expect(appt.isCallable, isFalse);
    });
  });

  group('Support ticket status mapping', () {
    test('round-trip بين enum وقيمة القاعدة', () {
      for (final s in TicketStatus.values) {
        expect(ticketStatusFromString(ticketStatusToDb(s)), s);
      }
    });
  });
}
