/// Full-screen Add/Edit Case form and the Task 07 quick-update dialog.
///
/// The form stays mobile-first and delegates all case writes to the repository.
/// Per-case notification choices use the local per-user preference table.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/pre_seeded_data.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/notifications/notification_plan.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/local_identity_service.dart';
import '../../features/accounts_and_profile/data/account_mode.dart';
import '../../core/utils/date_utils.dart';
import '../../database/app_database.dart';
import '../../features/settings/presentation/settings_controls.dart';
import '../../features/settings/presentation/settings_notifications/notification_time_picker.dart';
import '../../features/accounts_and_profile/data/local/firm_members_dao.dart';
import '../../features/accounts_and_profile/data/local/profiles_dao.dart';
import '../../features/cases/data/case_form_repository.dart';
import '../../features/cases/presentation/client_notification_flow.dart';
import '../../features/payments/presentation/lapse_allowance_ui.dart';
import '../../features/settings/data/local/case_notification_preferences_dao.dart';
import '../../features/settings/data/local/case_types_dao.dart';
import '../../features/settings/data/district_court_categories.dart';
import '../../features/settings/data/notification_day_offsets.dart';
import '../../features/settings/data/premium_access.dart';
import '../../features/settings/data/write_allowance.dart';
import '../../features/settings/data/local/court_categories_dao.dart';
import '../../features/settings/data/local/courts_dao.dart';
import '../../features/settings/data/local/on_behalfs_dao.dart';
import '../../features/settings/data/local/steps_dao.dart';
import '../../shared/providers/database_provider.dart';
import 'custom_dropdown.dart';
import 'date_picker_helper.dart';

String _seedLabel(BuildContext context, String id, String fallbackEn) =>
    context.l10n.seedLabel(id, fallbackEn: fallbackEn);

/// Effective local write permissions for the current identity.
class CaseWritePermissions {
  /// Creates a permission value.
  const CaseWritePermissions({required this.canAdd, required this.canEdit});

  /// Whether the identity may add cases.
  final bool canAdd;

  /// Whether the identity may edit cases.
  final bool canEdit;
}

/// Resolves cached firm permissions and fails closed when the cache is absent.
final caseWritePermissionsProvider = FutureProvider<CaseWritePermissions>((
  ref,
) async {
  final db = await ref.read(databaseProvider.future);
  // Keyed by the signed-in account when there is one (Task 17), the local
  // placeholder otherwise, so the caches are read under the id they were
  // written with.
  final userId = ref.read(accountCacheUserIdProvider);
  final profile = await ProfilesDao(db).getById(userId);
  if (profile?.firmId == null || profile?.role == 'owner') {
    return const CaseWritePermissions(canAdd: true, canEdit: true);
  }

  final members = await FirmMembersDao(db).getByUserId(userId);
  final member = members
      .where((item) => item.firmId == profile!.firmId)
      .firstOrNull;
  // A firm user without a cached membership row must not be allowed to write.
  return CaseWritePermissions(
    canAdd: member?.canAdd ?? false,
    canEdit: member?.canEdit ?? false,
  );
});

/// Data required by the form's cascading dropdowns.
class AddEditCaseLookupData {
  /// Creates lookup data for an add/edit form.
  const AddEditCaseLookupData({
    this.courtCategories = const [],
    this.caseCategories = const [],
    this.courts = const [],
    this.caseTypes = const [],
    this.onBehalfs = const [],
    this.steps = const [],
    this.notificationOffsets = notificationDayOffsetOptions,
    this.defaultNotificationOffset = defaultNotificationDayOffset,
    this.defaultNotificationTime = defaultNotificationMinutes,
    this.lastAddCaseHigherLowerCourt,
    this.lastAddCaseDivision,
    this.lastAddCaseDistrict,
  });

  /// All non-deleted court categories.
  final List<CourtCategory> courtCategories;

  /// All non-deleted AD/HCD case categories.
  final List<CaseCategory> caseCategories;

  /// All non-deleted courts.
  final List<Court> courts;

  /// All non-deleted case types.
  final List<CaseType> caseTypes;

  /// All non-deleted on-behalf roles.
  final List<OnBehalf> onBehalfs;

  /// All non-deleted procedural steps.
  final List<Step> steps;

  /// Available notification offsets from per-user notification settings.
  final List<int> notificationOffsets;

  /// The offset stored in Settings → Notifications, which a case without its
  /// own stored preference starts from.
  final int defaultNotificationOffset;

  /// The alert time stored in Settings → Notifications, which a case without
  /// its own Notification Time follows.
  final int defaultNotificationTime;

  /// Last Add Case court hierarchy choices saved for this user.
  final String? lastAddCaseHigherLowerCourt;
  final String? lastAddCaseDivision;
  final String? lastAddCaseDistrict;
}

/// Resolves the schema-required On Behalf foreign key without choosing between
/// multiple roles implicitly. A selected valid role wins; a sole role is safe
/// to infer; zero or multiple unselected roles require explicit user input.
OnBehalf? resolveOnBehalfSelection({
  required List<OnBehalf> options,
  OnBehalf? selected,
}) {
  if (selected != null && options.any((item) => item.id == selected.id)) {
    return selected;
  }
  return options.length == 1 ? options.single : null;
}

/// Day Offset a case starts from when it has no stored preference of its own:
/// the offset configured in Settings → Notifications.
///
/// Falls back to the first offered option when the stored offset is not one of
/// [options] (an older preference, or a value the field does not offer), so the
/// dropdown is never left empty.
List<int> resolveDefaultNotificationOffsets({
  required List<int> options,
  required int preferred,
}) {
  if (options.isEmpty) return const <int>[];
  return <int>[options.contains(preferred) ? preferred : options.first];
}

/// Full-screen mobile-first sheet for adding or editing a case.
class AddEditCaseSheet extends ConsumerStatefulWidget {
  /// Creates an add-mode form when [initialCase] is omitted.
  const AddEditCaseSheet({
    this.initialCase,
    this.lookupData,
    this.initialNextDate,
    this.canAdd = true,
    this.canEdit = true,
    this.onSave,
    super.key,
  });

  /// Existing case used to pre-fill edit mode.
  final Case? initialCase;

  /// Optional lookup data, primarily useful for deterministic widget tests.
  final AddEditCaseLookupData? lookupData;

  /// Optional initial date for add mode and deterministic form hosts/tests.
  final DateTime? initialNextDate;

  /// Initial add permission supplied by a host; firm permissions are resolved locally.
  final bool canAdd;

  /// Initial edit permission supplied by a host; firm permissions are resolved locally.
  final bool canEdit;

  /// Optional host callback invoked after a successful save.
  final VoidCallback? onSave;

  /// Opens the form as a full-height modal sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    Case? initialCase,
    AddEditCaseLookupData? lookupData,
    DateTime? initialNextDate,
    bool canAdd = true,
    bool canEdit = true,
    VoidCallback? onSave,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditCaseSheet(
        initialCase: initialCase,
        lookupData: lookupData,
        initialNextDate: initialNextDate,
        canAdd: canAdd,
        canEdit: canEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  ConsumerState<AddEditCaseSheet> createState() => _AddEditCaseSheetState();
}

class _AddEditCaseSheetState extends ConsumerState<AddEditCaseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _formMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _caseNumberController = TextEditingController();
  final _honorableJudgesController = TextEditingController();
  final _tenderNumberController = TextEditingController();
  final _previousCourtCaseController = TextEditingController();
  final _districtOfOriginController = TextEditingController();
  final _petitionerController = TextEditingController();
  final _petitionerCounselController = TextEditingController();
  final _respondentController = TextEditingController();
  final _respondentCounselController = TextEditingController();
  final _partyPhoneController = TextEditingController();
  final _caseTitleController = TextEditingController();
  final _caseRemarksController = TextEditingController();
  final _resultController = TextEditingController();
  final _noteController = TextEditingController();

  AddEditCaseLookupData? _lookupData;
  Object? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isNotificationEnabled = true;
  // This case's own alert time; null means it follows the Settings default.
  int? _notificationTimeMinutes;
  bool _notificationPreferenceLoading = false;
  bool _permissionResolved = false;
  bool _canAdd = true;
  bool _canEdit = true;
  bool _sheetEntranceComplete = false;
  bool _lookupLoadStarted = false;
  Animation<double>? _sheetAnimation;
  DateTime? _nextDate;
  String? _higherLowerCourt;
  String? _division;
  String? _district;
  String? _courtCategoryId;
  Court? _selectedCourt;
  CaseCategory? _selectedCaseCategory;
  CaseType? _selectedCaseType;
  OnBehalf? _selectedOnBehalf;
  List<Step> _selectedSteps = const [];
  List<int> _selectedNotificationOffsets = const [];
  bool _initializedFromCase = false;
  Future<void> _lastSelectionWrite = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _setTextControllers(widget.initialCase);
    if (widget.initialCase == null) {
      _nextDate = widget.initialNextDate;
    }
    if (widget.lookupData != null) {
      _lookupData = widget.lookupData;
      _isLoading = false;
      _sheetEntranceComplete = true;
      _notificationPreferenceLoading = widget.initialCase != null;
      _initializeSelection();
      _loadPermissions();
      _loadNotificationPreference();
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _observeSheetEntrance(),
    );
  }

  void _observeSheetEntrance() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _startLookupDataLoad();
      _revealLoadedForm();
      return;
    }
    _sheetAnimation = animation;
    animation.addStatusListener(_onSheetAnimationStatusChanged);
  }

  void _onSheetAnimationStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _sheetAnimation?.removeStatusListener(_onSheetAnimationStatusChanged);
    _sheetAnimation = null;
    _startLookupDataLoad();
    _revealLoadedForm();
  }

  void _startLookupDataLoad() {
    if (_lookupLoadStarted || widget.lookupData != null) return;
    _lookupLoadStarted = true;
    _loadLookupData();
  }

  void _revealLoadedForm() {
    if (!mounted || _sheetEntranceComplete) return;
    setState(() {
      _sheetEntranceComplete = true;
      if ((_lookupData != null || _loadError != null) && _isLoading) {
        _isLoading = false;
      }
    });
  }

  @override
  void dispose() {
    _sheetAnimation?.removeStatusListener(_onSheetAnimationStatusChanged);
    _caseNumberController.dispose();
    _honorableJudgesController.dispose();
    _tenderNumberController.dispose();
    _previousCourtCaseController.dispose();
    _districtOfOriginController.dispose();
    _petitionerController.dispose();
    _petitionerCounselController.dispose();
    _respondentController.dispose();
    _respondentCounselController.dispose();
    _partyPhoneController.dispose();
    _caseTitleController.dispose();
    _caseRemarksController.dispose();
    _resultController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setTextControllers(Case? currentCase) {
    if (currentCase == null) return;
    // Case number is one editable value; the slash remains part of the
    // stored/displayed value rather than splitting the field into two boxes.
    _caseNumberController.text = currentCase.caseNumber;
    _honorableJudgesController.text = currentCase.honorableJudges ?? '';
    _tenderNumberController.text = currentCase.tenderNumber ?? '';
    _previousCourtCaseController.text = currentCase.previousCourtCase ?? '';
    _districtOfOriginController.text = currentCase.districtOfOrigin ?? '';
    _petitionerController.text = currentCase.petitioner;
    _petitionerCounselController.text = currentCase.petitionerLeadCounsel ?? '';
    _respondentController.text = currentCase.respondent;
    _respondentCounselController.text = currentCase.respondentLeadCounsel ?? '';
    final storedPhone = currentCase.partyPhone ?? '';
    _partyPhoneController.text = storedPhone.startsWith('+88')
        ? storedPhone.substring(3)
        : storedPhone.replaceFirst(RegExp(r'^\+?88'), '');
    _caseTitleController.text = currentCase.caseTitleAndSection ?? '';
    _caseRemarksController.text = currentCase.caseRemarks ?? '';
    _resultController.text = currentCase.result ?? '';
    _noteController.text = currentCase.notesResults ?? '';
    _nextDate = currentCase.nextDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(currentCase.nextDate!);
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await ref.read(caseWritePermissionsProvider.future);
      if (!mounted) return;
      setState(() {
        _permissionResolved = true;
        _canAdd = permissions.canAdd;
        _canEdit = permissions.canEdit;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _permissionResolved = true;
        _canAdd = false;
        _canEdit = false;
      });
    }
  }

  Future<void> _loadNotificationPreference() async {
    if (widget.initialCase == null) return;
    try {
      final db = await ref.read(databaseProvider.future);
      final identity = ref.read(localIdentityServiceProvider);
      final preference = await CaseNotificationPreferencesDao(
        db,
      ).get(identity.getId(), widget.initialCase!.id);
      if (!mounted) return;
      setState(() {
        _notificationPreferenceLoading = false;
        if (preference != null) {
          _isNotificationEnabled = preference.enabled;
          _notificationTimeMinutes = preference.timeMinutes;
          _selectedNotificationOffsets = _decodeOffsets(
            preference.offsets,
            fallback: _lookupData?.defaultNotificationOffset,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _notificationPreferenceLoading = false);
      // A missing or malformed preference must not prevent editing the case.
    }
  }

  Future<void> _loadLookupData() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final settingsRepository = await ref.read(
        settingsRepositoryProvider.future,
      );
      final settings = await settingsRepository.getSettings();
      final permissions = await ref.read(caseWritePermissionsProvider.future);
      final identity = ref.read(localIdentityServiceProvider);
      final data = AddEditCaseLookupData(
        courtCategories: await CourtCategoriesDao(db).getAll(),
        caseCategories:
            await (db.select(db.caseCategories)
                  ..where((row) => row.isDeleted.equals(false))
                  ..orderBy([
                    (row) => OrderingTerm(expression: row.orderIndex),
                  ]))
                .get(),
        courts: await CourtsDao(db).getAll(),
        caseTypes: await CaseTypesDao(db).getAll(),
        onBehalfs: await OnBehalfsDao(db).getAll(),
        steps: await StepsDao(db).getAll(),
        notificationOffsets: notificationDayOffsetOptions,
        defaultNotificationOffset: settings.notificationDayOffset,
        defaultNotificationTime:
            settings.notificationTime ?? defaultNotificationMinutes,
        lastAddCaseHigherLowerCourt: settings.lastAddCaseHigherLowerCourt,
        lastAddCaseDivision: settings.lastAddCaseDivision,
        lastAddCaseDistrict: settings.lastAddCaseDistrict,
      );
      CaseNotificationPreference? casePreference;
      if (widget.initialCase != null) {
        casePreference = await CaseNotificationPreferencesDao(
          db,
        ).get(identity.getId(), widget.initialCase!.id);
      }
      if (!mounted) return;
      setState(() {
        _lookupData = data;
        _isLoading = !_sheetEntranceComplete;
        _permissionResolved = true;
        _canAdd = permissions.canAdd;
        _canEdit = permissions.canEdit;
        // The case's own choice if it has one, else the Settings default — the
        // same rule that decides whether it alerts, so what this toggle shows is
        // what will actually happen. A case whose toggle reads On always alerts.
        _isNotificationEnabled =
            casePreference?.enabled ?? settings.notificationEnabled;
        if (casePreference != null) {
          _notificationTimeMinutes = casePreference.timeMinutes;
          _selectedNotificationOffsets = _decodeOffsets(
            casePreference.offsets,
            fallback: data.defaultNotificationOffset,
          );
        }
      });
      _initializeSelection();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = !_sheetEntranceComplete;
      });
    }
  }

  List<int> _decodeOffsets(String? raw, {int? fallback}) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<num>()
              .map((value) => value.toInt())
              .toList();
        }
      } on FormatException {
        // Ignore malformed local preference data and use the default below.
      }
    }
    return fallback == null ? const [] : [fallback];
  }

  bool get _hasWritePermission =>
      _permissionResolved &&
      (widget.initialCase == null
          ? widget.canAdd && _canAdd
          : widget.canEdit && _canEdit);

  void _initializeSelection() {
    if (_initializedFromCase || _lookupData == null) return;
    _initializedFromCase = true;
    final data = _lookupData!;
    final currentCase = widget.initialCase;
    if (currentCase != null) {
      _selectedCourt = _findById(
        data.courts,
        currentCase.courtId,
        (item) => item.id,
      );
      if (_selectedCourt != null) {
        // Higher-court category IDs are also the dropdown values; the
        // database's higher/lower discriminator remains `higher_courts`.
        _higherLowerCourt =
            _selectedCourt!.higherLowerCourts == higherCourtsOption
            ? _selectedCourt!.courtCategoryId
            : lowerCourtsOption;
        _division = _selectedCourt!.division;
        _district = _selectedCourt!.district;
        _courtCategoryId = _selectedCourt!.courtCategoryId;
      }
      _selectedCaseType =
          _findById(data.caseTypes, currentCase.caseType, (item) => item.id) ??
          _findByName(
            data.caseTypes,
            currentCase.caseType,
            (item) => item.name,
          );
      _selectedCaseCategory = _findById(
        data.caseCategories,
        currentCase.caseCategoryId ?? _selectedCaseType?.caseCategoryId ?? '',
        (item) => item.id,
      );
      _selectedOnBehalf = _findById(
        data.onBehalfs,
        currentCase.onBehalfId,
        (item) => item.id,
      );
      final storedSteps = (currentCase.lastStep ?? '')
          .split(',')
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toSet();
      _selectedSteps = data.steps
          .where(
            (step) =>
                storedSteps.contains(step.stepName) ||
                storedSteps.contains(step.id),
          )
          .toList(growable: false);
    } else {
      final rememberedHigherLower = data.lastAddCaseHigherLowerCourt;
      if (rememberedHigherLower == lowerCourtsOption) {
        _higherLowerCourt = rememberedHigherLower;
        final rememberedDivision = data.lastAddCaseDivision;
        if (rememberedDivision != null &&
            allDivisionIds.contains(rememberedDivision)) {
          _division = rememberedDivision;
          final rememberedDistrict = data.lastAddCaseDistrict;
          if (rememberedDistrict != null &&
              (districtIdsByDivision[rememberedDivision] ?? const []).contains(
                rememberedDistrict,
              )) {
            _district = rememberedDistrict;
          }
        }
      } else if (rememberedHigherLower == appellateDivisionId ||
          rememberedHigherLower == highCourtDivisionId) {
        _higherLowerCourt = rememberedHigherLower;
        _courtCategoryId = rememberedHigherLower;
      }
    }
    if (_selectedNotificationOffsets.isEmpty) {
      _selectedNotificationOffsets = resolveDefaultNotificationOffsets(
        options: data.notificationOffsets,
        preferred: data.defaultNotificationOffset,
      );
    }
    if (mounted) setState(() {});
  }

  T? _findById<T>(List<T> values, String id, String Function(T) getId) {
    for (final value in values) {
      if (getId(value) == id) return value;
    }
    return null;
  }

  T? _findByName<T>(List<T> values, String name, String Function(T) getName) {
    for (final value in values) {
      if (getName(value) == name) return value;
    }
    return null;
  }

  bool get _isLowerCourt => _higherLowerCourt == lowerCourtsOption;

  bool get _isHigherCourt =>
      _higherLowerCourt == appellateDivisionId ||
      _higherLowerCourt == highCourtDivisionId;

  // Court categories that actually exist for the selected district: the
  // pre-seeded ones with at least one court there (most districts have no
  // metropolitan courts, so those are omitted rather than offered as empty
  // dropdowns) plus the categories the user created for this district in
  // Settings → Edit Court/Steps → Lower Court Categories.
  List<CourtCategory> get _lowerCategories => districtCourtCategories(
    categories: _lookupData!.courtCategories,
    courts: _lookupData!.courts,
    division: _division,
    district: _district,
  );

  List<String> get _districtOptions =>
      districtIdsByDivision[_division] ?? const [];

  List<Court> get _courtOptions {
    final data = _lookupData!;
    return data.courts
        .where((court) {
          if (_isLowerCourt) {
            return court.higherLowerCourts == lowerCourtsOption &&
                court.courtCategoryId == _courtCategoryId &&
                court.division == _division &&
                court.district == _district;
          }
          return court.higherLowerCourts == higherCourtsOption &&
              court.courtCategoryId == _courtCategoryId;
        })
        .toList(growable: false);
  }

  List<CaseType> get _caseTypeOptions => _lookupData!.caseTypes
      .where(
        (item) =>
            item.courtCategoryId == _courtCategoryId &&
            (!_isHigherCourt ||
                item.caseCategoryId == _selectedCaseCategory?.id),
      )
      .toList(growable: false);

  List<CaseCategory> get _caseCategoryOptions => _lookupData!.caseCategories
      .where((item) => item.courtCategoryId == _courtCategoryId)
      .toList(growable: false);

  List<OnBehalf> get _onBehalfOptions => _lookupData!.onBehalfs
      .where((item) => item.courtCategoryId == _courtCategoryId)
      .toList(growable: false);

  List<Step> get _stepOptions => _lookupData!.steps
      .where((item) => item.courtCategoryId == _courtCategoryId)
      .toList(growable: false);

  String _caseCategoryLabel(BuildContext context, CaseCategory category) {
    final isBengali = Localizations.localeOf(context).languageCode == 'bn';
    return (isBengali
            ? caseCategoryLabelBn
            : caseCategoryLabelEn)[category.id] ??
        category.name;
  }

  String _categoryLabel(BuildContext context, CourtCategory category) {
    final l = AppLocalizations.of(context);
    return switch (category.nameKey) {
      'courtCategory_appellateDivision' => l.courtCategory_appellateDivision,
      'courtCategory_highCourtDivision' => l.courtCategory_highCourtDivision,
      'lowerCourtCategory_districtSessionsCriminal' =>
        l.lowerCourtCategory_districtSessionsCriminal,
      'lowerCourtCategory_districtCourtsCivil' =>
        l.lowerCourtCategory_districtCourtsCivil,
      'lowerCourtCategory_metropolitanSessionsJudgeCriminal' =>
        l.lowerCourtCategory_metropolitanSessionsJudgeCriminal,
      'lowerCourtCategory_chiefJudicialMagistrate' =>
        l.lowerCourtCategory_chiefJudicialMagistrate,
      'lowerCourtCategory_chiefMetropolitanMagistrate' =>
        l.lowerCourtCategory_chiefMetropolitanMagistrate,
      'lowerCourtCategory_executiveMagistrate' =>
        l.lowerCourtCategory_executiveMagistrate,
      'lowerCourtCategory_tribunals' => l.lowerCourtCategory_tribunals,
      _ => category.nameKey,
    };
  }

  String _divisionLabel(BuildContext context, String id) {
    final l = AppLocalizations.of(context);
    return switch (id) {
      divisionDhakaId => l.division_dhaka,
      divisionChattogramId => l.division_chattagram,
      divisionRajshahiId => l.division_rajshahi,
      divisionKhulnaId => l.division_khulna,
      divisionBarishalId => l.division_barishal,
      divisionSylhetId => l.division_sylhet,
      divisionRangpurId => l.division_rangpur,
      divisionMymensinghId => l.division_mymensingh,
      _ => id,
    };
  }

  String _higherLowerLabel(BuildContext context, String id) {
    final l = AppLocalizations.of(context);
    return switch (id) {
      appellateDivisionId => l.courtCategory_appellateDivision,
      highCourtDivisionId => l.courtCategory_highCourtDivision,
      lowerCourtsOption => l.courtCategory_lowerDivisionalCourts,
      _ => id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      // Keep the form gray so each white section reads as a distinct card.
      color: AppColors.surfaceVariant,
      child: ScaffoldMessenger(
        key: _formMessengerKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              return SizedBox(
                height: height,
                child: Column(
                  children: [
                    _SheetHeader(
                      title: widget.initialCase == null
                          ? l.addEditCaseSheet_title
                          : l.addEditCaseSheet_editTitle,
                    ),
                    Expanded(child: _buildBody(context)),
                    _SheetFooter(
                      label: l.addEditCaseSheet_save,
                      enabled:
                          _hasWritePermission &&
                          !_isLoading &&
                          !_isSaving &&
                          !_notificationPreferenceLoading,
                      onPressed: _save,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(child: Text('Unable to load case form data: $_loadError'));
    }
    if (_lookupData == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final editable = _hasWritePermission;
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('add-edit-form-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _sectionCard(
            key: const ValueKey('add-edit-section-court'),
            title: l.addEditCaseSheet_sectionCourt,
            children: [
              CustomDropdown<String>(
                fieldKey: const ValueKey('add-edit-higher-lower-court'),
                label: l.addEditCaseSheet_higherOrLowerCourt,
                items: const [
                  appellateDivisionId,
                  highCourtDivisionId,
                  lowerCourtsOption,
                ],
                value: _higherLowerCourt,
                itemLabel: (item) => _higherLowerLabel(context, item),
                enabled: editable,
                emptyFillColor: AppColors.surface,
                selectedFillColor: AppColors.surfaceVariant,
                outlined: true,
                onChanged: _onHigherLowerChanged,
              ),
              if (_isLowerCourt) ...[
                const SizedBox(height: AppSpacing.md),
                CustomDropdown<String>(
                  fieldKey: const ValueKey('add-edit-division'),
                  label: l.addEditCaseSheet_division,
                  items: allDivisionIds,
                  value: _division,
                  itemLabel: (item) => _divisionLabel(context, item),
                  enabled: editable,
                  emptyFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surfaceVariant,
                  outlined: true,
                  onChanged: _onDivisionChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                CustomDropdown<String>(
                  fieldKey: const ValueKey('add-edit-district'),
                  label: l.addEditCaseSheet_district,
                  items: _districtOptions,
                  value: _district,
                  itemLabel: (item) =>
                      _seedLabel(context, item, districtLabelEn[item] ?? item),
                  enabled: editable && _division != null,
                  emptyFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surfaceVariant,
                  outlined: true,
                  onDisabledTap: editable && _division == null
                      ? () =>
                            _showDependencyMessage(l.addEditCaseSheet_division)
                      : null,
                  onChanged: _onDistrictChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                CustomDropdown<CourtCategory>(
                  fieldKey: const ValueKey('add-edit-court-category'),
                  label: l.addEditCaseSheet_courtCategory,
                  items: _lowerCategories,
                  value: _categoryById(_courtCategoryId),
                  itemLabel: (item) => _categoryLabel(context, item),
                  enabled: editable && _district != null,
                  emptyFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surfaceVariant,
                  outlined: true,
                  onDisabledTap: editable && _district == null
                      ? () =>
                            _showDependencyMessage(l.addEditCaseSheet_district)
                      : null,
                  onChanged: (value) => _onCategoryChanged(value?.id),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              CustomDropdown<Court>(
                fieldKey: const ValueKey('add-edit-name-of-court'),
                label: l.addEditCaseSheet_nameOfCourt,
                items: _courtOptions,
                value: _selectedCourt,
                searchable: true,
                itemLabel: (item) =>
                    _seedLabel(context, item.id, item.courtName),
                enabled: editable && _courtCategoryId != null,
                emptyFillColor: AppColors.surface,
                selectedFillColor: AppColors.surfaceVariant,
                outlined: true,
                onDisabledTap: editable && _courtCategoryId == null
                    ? () => _showDependencyMessage(
                        l.addEditCaseSheet_courtCategory,
                      )
                    : null,
                onChanged: _onCourtChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isHigherCourt) ...[
                _textField(
                  key: const ValueKey('add-edit-honorable-judges'),
                  label: l.addEditCaseSheet_honorableJudges,
                  controller: _honorableJudgesController,
                  enabled: editable,
                ),
                const SizedBox(height: AppSpacing.md),
                CustomDropdown<CaseCategory>(
                  fieldKey: const ValueKey('add-edit-case-category'),
                  label: l.addEditCaseSheet_caseCategory,
                  items: _caseCategoryOptions,
                  value: _selectedCaseCategory,
                  itemLabel: (item) => _caseCategoryLabel(context, item),
                  enabled: editable && _courtCategoryId != null,
                  emptyFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surfaceVariant,
                  outlined: true,
                  onDisabledTap: editable && _courtCategoryId == null
                      ? () => _showDependencyMessage(
                          l.addEditCaseSheet_nameOfCourt,
                        )
                      : null,
                  onChanged: (value) => _onCaseCategoryChanged(value?.id),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _labeledTextField(
                      fieldKey: const ValueKey('add-edit-case-type'),
                      label: l.allCasesScreen_caseType,
                      child: CustomDropdown<CaseType>(
                        label: null,
                        modalTitle: l.allCasesScreen_caseType,
                        items: _caseTypeOptions,
                        value: _selectedCaseType,
                        itemLabel: (item) =>
                            _seedLabel(context, item.id, item.name),
                        enabled: editable && _courtCategoryId != null,
                        emptyFillColor: AppColors.surface,
                        selectedFillColor: AppColors.surfaceVariant,
                        outlined: true,
                        onDisabledTap: editable && _courtCategoryId == null
                            ? () => _showDependencyMessage(
                                l.addEditCaseSheet_courtCategory,
                              )
                            : null,
                        onChanged: (value) =>
                            setState(() => _selectedCaseType = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _labeledTextField(
                      fieldKey: const ValueKey(
                        'add-edit-case-number-container',
                      ),
                      label: l.addEditCaseSheet_caseNumber,
                      child: _caseNumberFields(context, editable),
                    ),
                  ),
                ],
              ),
              if (_isHigherCourt) ...[
                const SizedBox(height: AppSpacing.md),
                _textField(
                  key: const ValueKey('add-edit-tender-number'),
                  label: l.addEditCaseSheet_tenderNumber,
                  controller: _tenderNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: editable,
                ),
                const SizedBox(height: AppSpacing.md),
                _textField(
                  key: const ValueKey('add-edit-previous-court-case'),
                  label: l.addEditCaseSheet_previousCourtCase,
                  controller: _previousCourtCaseController,
                  enabled: editable,
                ),
                const SizedBox(height: AppSpacing.md),
                _textField(
                  key: const ValueKey('add-edit-district-of-origin'),
                  label: l.addEditCaseSheet_districtOfOrigin,
                  controller: _districtOfOriginController,
                  enabled: editable,
                ),
              ],
            ],
          ),
          _sectionCard(
            key: const ValueKey('add-edit-section-parties'),
            title: l.addEditCaseSheet_sectionParties,
            children: [
              _partyFields(
                l.addEditCaseSheet_petitioner,
                _petitionerController,
                _petitionerCounselController,
                const ValueKey('add-edit-petitioner'),
                const ValueKey('add-edit-petitioner-lead-counsel'),
                editable,
                l.addEditCaseSheet_petitionerLeadCounsel,
              ),
              const SizedBox(height: 56),
              _partyFields(
                l.addEditCaseSheet_respondent,
                _respondentController,
                _respondentCounselController,
                const ValueKey('add-edit-respondent'),
                const ValueKey('add-edit-respondent-lead-counsel'),
                editable,
                l.addEditCaseSheet_respondentLeadCounsel,
              ),
              const SizedBox(height: 56),
              CustomDropdown<OnBehalf>(
                fieldKey: const ValueKey('add-edit-on-behalf'),
                label: l.addEditCaseSheet_onBehalf,
                items: _onBehalfOptions,
                value: _selectedOnBehalf,
                // Pre-seeded on-behalfs are stored with their English name, so
                // the label comes from the seed data like every other option.
                itemLabel: (item) => _seedLabel(context, item.id, item.name),
                enabled: editable && _courtCategoryId != null,
                emptyFillColor: AppColors.surface,
                selectedFillColor: AppColors.surfaceVariant,
                outlined: true,
                onDisabledTap: editable && _courtCategoryId == null
                    ? () => _showDependencyMessage(
                        l.addEditCaseSheet_courtCategory,
                      )
                    : null,
                onChanged: (value) => setState(() => _selectedOnBehalf = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _partyPhoneField(context, editable),
            ],
          ),
          _sectionCard(
            key: const ValueKey('add-edit-section-details'),
            title: l.addEditCaseSheet_sectionDetails,
            children: [
              _textField(
                key: const ValueKey('add-edit-case-title'),
                label: l.addEditCaseSheet_caseTitleAndSection,
                controller: _caseTitleController,
                enabled: editable,
              ),
              const SizedBox(height: AppSpacing.md),
              _textField(
                key: const ValueKey('add-edit-case-remarks'),
                label: l.addEditCaseSheet_caseRemarks,
                controller: _caseRemarksController,
                maxLines: 3,
                enabled: editable,
              ),
            ],
          ),
          _sectionCard(
            key: const ValueKey('add-edit-section-schedule'),
            title: l.addEditCaseSheet_sectionSchedule,
            children: [
              _nextDateAndNotificationRow(context, editable),
              const SizedBox(height: AppSpacing.md),
              // Day Offset and Notification Time share one line: how early the
              // alert goes out on the left, what time of day on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomDropdown<int>(
                      fieldKey: const ValueKey('add-edit-day-offset'),
                      label: l.addEditCaseSheet_dayOffset,
                      items: _lookupData?.notificationOffsets ?? const [],
                      selectedValues: _selectedNotificationOffsets,
                      multiSelect: true,
                      searchable: false,
                      itemLabel: (item) => _offsetLabel(context, item),
                      enabled: editable,
                      emptyFillColor: AppColors.surface,
                      selectedFillColor: AppColors.surfaceVariant,
                      outlined: true,
                      // The same window Settings → Notifications uses.
                      onOpenPicker: () => _pickNotificationOffsets(context),
                      onMultiChanged: (values) =>
                          setState(() => _selectedNotificationOffsets = values),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _notificationTimeField(context, editable)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isHigherCourt)
                _textField(
                  key: const ValueKey('add-edit-result'),
                  label: l.addEditCaseSheet_result,
                  controller: _resultController,
                  maxLines: 3,
                  enabled: editable,
                ),
              if (_isHigherCourt) const SizedBox(height: AppSpacing.md),
              if (!_isHigherCourt)
                CustomDropdown<Step>(
                  fieldKey: const ValueKey('add-edit-step'),
                  label: l.addEditCaseSheet_step,
                  items: _stepOptions,
                  selectedValues: _selectedSteps,
                  multiSelect: true,
                  itemLabel: (item) =>
                      _seedLabel(context, item.id, item.stepName),
                  enabled: editable && _courtCategoryId != null,
                  emptyFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surfaceVariant,
                  outlined: true,
                  onDisabledTap: editable && _courtCategoryId == null
                      ? () => _showDependencyMessage(
                          l.addEditCaseSheet_courtCategory,
                        )
                      : null,
                  onMultiChanged: (values) =>
                      setState(() => _selectedSteps = values),
                ),
              const SizedBox(height: AppSpacing.md),
              _textField(
                key: const ValueKey('add-edit-note'),
                label: l.addEditCaseSheet_note,
                controller: _noteController,
                maxLines: 4,
                enabled: editable,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required Key key,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMd,
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _labeledTextField({
    required Key fieldKey,
    required String label,
    required Widget child,
  }) {
    return KeyedSubtree(
      key: fieldKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTypography.labelLg),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _partyFields(
    String label,
    TextEditingController party,
    TextEditingController counsel,
    Key partyKey,
    Key counselKey,
    bool enabled,
    String counselLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(
          key: partyKey,
          label: label,
          controller: party,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.sm),
        _textField(
          key: counselKey,
          label: counselLabel,
          controller: counsel,
          enabled: enabled,
        ),
      ],
    );
  }

  /// Builds the unrestricted plain-text Case Number input.
  Widget _caseNumberFields(BuildContext context, bool enabled) {
    return _textField(
      key: const ValueKey('add-edit-case-number'),
      label: AppLocalizations.of(context).addEditCaseSheet_caseNumber,
      controller: _caseNumberController,
      enabled: enabled,
      showInputLabel: false,
    );
  }

  Widget _partyPhoneField(BuildContext context, bool enabled) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.addEditCaseSheet_partyPhone, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('add-edit-party-phone-prefix'),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Text('+88', style: AppTypography.bodyMd),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _textField(
                  key: const ValueKey('add-edit-party-phone'),
                  label: l.addEditCaseSheet_partyPhone,
                  controller: _partyPhoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: enabled,
                  showInputLabel: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required Key key,
    required String label,
    required TextEditingController controller,
    required bool enabled,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool showInputLabel = true,
  }) {
    final isEmpty = controller.text.trim().isEmpty;
    final emptyOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final filledOutline = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final emptyFocusedOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final filledFocusedOutline = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.secondary, width: 2),
    );
    final field = TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        fillColor: isEmpty ? AppColors.surface : AppColors.surfaceVariant,
        enabledBorder: isEmpty ? emptyOutline : filledOutline,
        focusedBorder: isEmpty ? emptyFocusedOutline : filledFocusedOutline,
      ),
    );
    if (!showInputLabel) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }

  void _showDependencyMessage(String dependencyLabel) {
    final messenger = _formMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xxxl,
          ),
          content: Text(
            AppLocalizations.of(
              context,
            ).addEditCaseSheet_dependencyRequired(dependencyLabel),
          ),
        ),
      );
  }

  Widget _nextDateAndNotificationRow(BuildContext context, bool editable) {
    final l = AppLocalizations.of(context);
    final dateText = _nextDate == null
        ? ''
        : DateFormat(
            'dd/MM/yy, EEE',
            Localizations.localeOf(context).toLanguageTag(),
          ).format(_nextDate!);
    final emptyDateBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final filledDateBorder = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.addEditCaseSheet_nextDate, style: AppTypography.labelLg),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                key: const ValueKey('add-edit-next-date'),
                onTap: editable ? _pickNextDate : null,
                child: InputDecorator(
                  isEmpty: dateText.isEmpty,
                  decoration: InputDecoration(
                    enabled: editable,
                    fillColor: dateText.isEmpty
                        ? AppColors.surface
                        : AppColors.surfaceVariant,
                    enabledBorder: dateText.isEmpty
                        ? emptyDateBorder
                        : filledDateBorder,
                    focusedBorder: dateText.isEmpty
                        ? emptyDateBorder
                        : filledDateBorder,
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    dateText.isEmpty ? l.addEditCaseSheet_pickDate : dateText,
                    style: AppTypography.bodyMd.copyWith(
                      color: dateText.isEmpty
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Text(
                l.addEditCaseSheet_notification,
                style: AppTypography.labelMd,
              ),
              IconButton(
                key: const ValueKey('add-edit-notification'),
                tooltip: l.addEditCaseSheet_notification,
                onPressed: editable
                    ? () => setState(
                        () => _isNotificationEnabled = !_isNotificationEnabled,
                      )
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: _isNotificationEnabled
                      ? Colors.black
                      : Colors.transparent,
                  foregroundColor: _isNotificationEnabled
                      ? Colors.white
                      : Colors.black,
                  side: _isNotificationEnabled
                      ? null
                      : const BorderSide(color: Colors.black, width: 2),
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  _isNotificationEnabled
                      ? Icons.notifications
                      : Icons.notifications_none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the same day-offset window Settings → Notifications uses.
  Future<void> _pickNotificationOffsets(BuildContext context) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsMultiSelectDialog<int>(
        title: l.settingsNotifications_selectDayOffsetTitle,
        order: _lookupData?.notificationOffsets ?? notificationDayOffsetOptions,
        selected: _selectedNotificationOffsets.toSet(),
        labelOf: (offset) => _offsetLabel(context, offset),
        popoverWindow: true,
        minSelected: 1,
        minSelectedMessage: l.settingsNotifications_keepOneOffset,
        onChanged: (_, chosen) =>
            setState(() => _selectedNotificationOffsets = chosen),
      ),
    );
  }

  String _offsetLabel(BuildContext context, int offset) {
    final l = AppLocalizations.of(context);
    return offset == 0
        ? l.addEditCaseSheet_offsetSameDay
        : offset == 1
        ? l.addEditCaseSheet_offsetDayBefore
        : l.addEditCaseSheet_offsetDaysBefore(offset);
  }

  /// This case's Notification Time: follows the Settings default until the user
  /// picks its own, and tapping opens the very window Settings opens.
  Widget _notificationTimeField(BuildContext context, bool editable) {
    final l = AppLocalizations.of(context);
    final effective =
        _notificationTimeMinutes ?? _lookupData!.defaultNotificationTime;
    final isOverride = _notificationTimeMinutes != null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.settingsNotifications_timeLabel, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          key: const ValueKey('add-edit-notification-time'),
          onTap: editable ? () => _pickNotificationTime(effective) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              enabled: editable,
              fillColor: AppColors.surfaceVariant,
              enabledBorder: border,
              focusedBorder: border,
              // The reset clears this case's override, handing it back to the
              // Settings default; it only appears while there is one to clear.
              suffixIcon: isOverride
                  ? IconButton(
                      key: const ValueKey('add-edit-notification-time-reset'),
                      tooltip: l.settingsViewSettings_fontSizeReset,
                      onPressed: editable
                          ? () =>
                                setState(() => _notificationTimeMinutes = null)
                          : null,
                      icon: const Icon(Icons.restart_alt),
                    )
                  : const Icon(Icons.schedule),
            ),
            child: Text(
              AppDateUtils.formatClockTime(
                effective,
                locale: Localizations.localeOf(context).languageCode,
              ),
              style: AppTypography.bodyMd,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickNotificationTime(int initialMinutes) async {
    final picked = await showNotificationTimePicker(
      context,
      initialMinutes: initialMinutes,
    );
    if (picked == null || !mounted) return;
    setState(() => _notificationTimeMinutes = picked.hour * 60 + picked.minute);
  }

  Future<void> _pickNextDate() async {
    final date = await showPlainDatePicker(
      context,
      initialDate: _nextDate,
      styleActions: true,
    );
    if (date != null && mounted) setState(() => _nextDate = date);
  }

  CourtCategory? _categoryById(String? id) => id == null
      ? null
      : _lowerCategories.where((item) => item.id == id).firstOrNull;

  void _onHigherLowerChanged(String? value) {
    if (value == null) return;
    setState(() {
      _higherLowerCourt = value;
      _division = null;
      _district = null;
      _selectedCourt = null;
      _selectedCaseCategory = null;
      _selectedCaseType = null;
      _selectedOnBehalf = null;
      _selectedSteps = const [];
      _courtCategoryId = value == lowerCourtsOption ? null : value;
    });
    _queueLastAddCaseSelectionWrite();
  }

  void _onDivisionChanged(String? value) {
    setState(() {
      _division = value;
      _district = null;
      _selectedCourt = null;
      _selectedCaseCategory = null;
      _selectedCaseType = null;
      _selectedOnBehalf = null;
      _selectedSteps = const [];
    });
    _queueLastAddCaseSelectionWrite();
  }

  void _onDistrictChanged(String? value) {
    setState(() {
      _district = value;
      _selectedCourt = null;
      _selectedCaseCategory = null;
      _selectedCaseType = null;
      _selectedOnBehalf = null;
      _selectedSteps = const [];
    });
    _queueLastAddCaseSelectionWrite();
  }

  /// Serializes preference writes so quick cascading taps cannot overwrite a
  /// newer selection with an older read-modify-write result.
  void _queueLastAddCaseSelectionWrite() {
    if (widget.initialCase != null) return;
    final higherLowerCourt = _higherLowerCourt;
    final division = _division;
    final district = _district;
    _lastSelectionWrite = _lastSelectionWrite.then((_) async {
      try {
        final repository = await ref.read(settingsRepositoryProvider.future);
        await repository.saveLastAddCaseSelection(
          higherLowerCourt: higherLowerCourt,
          division: division,
          district: district,
        );
        ref.read(pushPreferencesProvider)();
      } catch (_) {
        // Preference persistence is best-effort and must not block case entry.
      }
    });
  }

  void _onCategoryChanged(String? value) => setState(() {
    _courtCategoryId = value;
    _selectedCaseCategory = null;
    _selectedCourt = null;
    _selectedCaseType = null;
    _selectedOnBehalf = null;
    _selectedSteps = const [];
  });

  void _onCourtChanged(Court? value) => setState(() {
    _selectedCourt = value;
    if (value != null) {
      _courtCategoryId = value.courtCategoryId;
      _selectedCaseCategory = null;
      _selectedCaseType = null;
    }
  });

  void _onCaseCategoryChanged(String? value) => setState(() {
    _selectedCaseCategory = value == null
        ? null
        : _caseCategoryOptions.where((item) => item.id == value).firstOrNull;
    _selectedCaseType = null;
  });

  String? _requiredError(String label, String? value) =>
      value == null || value.trim().isEmpty ? '$label is required' : null;

  String? _validate() {
    final l = AppLocalizations.of(context);
    if (_higherLowerCourt == null) {
      return _requiredError(l.addEditCaseSheet_higherOrLowerCourt, null);
    }
    if (_isLowerCourt) {
      if (_division == null) {
        return _requiredError(l.addEditCaseSheet_division, null);
      }
      if (_district == null) {
        return _requiredError(l.addEditCaseSheet_district, null);
      }
      if (_courtCategoryId == null) {
        return _requiredError(l.addEditCaseSheet_courtCategory, null);
      }
    }
    if (_selectedCourt == null) {
      return _requiredError(l.addEditCaseSheet_nameOfCourt, null);
    }
    if (_isHigherCourt && _selectedCaseCategory == null) {
      return _requiredError(l.addEditCaseSheet_caseCategory, null);
    }
    if (_selectedCaseType == null) {
      return _requiredError(l.allCasesScreen_caseType, null);
    }
    if (_requiredError(
          l.addEditCaseSheet_caseNumber,
          _caseNumberController.text,
        ) !=
        null) {
      return _requiredError(
        l.addEditCaseSheet_caseNumber,
        _caseNumberController.text,
      );
    }
    if (_nextDate == null) {
      return _requiredError(l.addEditCaseSheet_nextDate, null);
    }
    return null;
  }

  Future<void> _save() async {
    // Keep authorization at the write boundary; a disabled button is not
    // sufficient protection against programmatic or stale UI invocation.
    if (!_hasWritePermission) return;
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = await ref.read(databaseProvider.future);
      final repository = await ref.read(
        transactionalCaseRepositoryProvider.future,
      );
      final formRepository = CaseFormRepository(db, repository);
      final identity = ref.read(localIdentityServiceProvider);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      // Phase 10's allowance, resolved at the write boundary so a stale form
      // cannot save past it: genuinely free keeps the 50-case wall, a lapsed
      // paid account keeps writing up to its tier's allowance, premium has no
      // ceiling. Premium entitlement is derived from subscription expiry, never
      // from the display-only status flag or a per-user view preference.
      final hasPremiumAccess = await resolvePremiumAccess(db, identity.getId());
      final allowance = await resolveWriteAllowance(
        db,
        tier: ref.read(allowanceTierProvider),
        premium: hasPremiumAccess,
      );
      if (widget.initialCase == null) {
        if (!allowance.canAddCase()) {
          if (mounted) {
            setState(() => _isSaving = false);
            context.push(
              allowance.isLapsed
                  ? AppRoutes.paywallFromLapse
                  : AppRoutes.paywallFromCaseLimit,
            );
          }
          return;
        }
      } else if (!allowance.isCaseWritable(widget.initialCase!.id)) {
        // Beyond the allowance the case stays readable but not writable; the
        // refusal names the reason instead of silently doing nothing.
        if (mounted) {
          setState(() => _isSaving = false);
          showReadOnlyWriteMessage(
            context,
            AppLocalizations.of(context).lapse_readOnlyCase,
          );
        }
        return;
      }
      // The UI field is optional in the confirmed mandatory-field list, but
      // the local schema requires a valid FK. Auto-resolve only an unambiguous
      // single role; otherwise require the user to choose explicitly.
      final onBehalf = resolveOnBehalfSelection(
        options: _onBehalfOptions,
        selected: _selectedOnBehalf,
      );
      final categoryOnBehalfs = _onBehalfOptions;
      if (onBehalf == null) {
        throw StateError(
          categoryOnBehalfs.isEmpty
              ? 'No on-behalf option exists for the selected category'
              : 'Select an on-behalf option before saving',
        );
      }
      final companion = CasesCompanion(
        id: widget.initialCase == null
            ? const Value.absent()
            : Value(widget.initialCase!.id),
        courtId: Value(_selectedCourt!.id),
        caseCategoryId: Value(
          _isHigherCourt ? _selectedCaseCategory?.id : null,
        ),
        caseType: Value(_selectedCaseType!.name),
        caseNumber: Value(_composeCaseNumber()),
        honorableJudges: Value(
          _isHigherCourt ? _emptyToNull(_honorableJudgesController.text) : null,
        ),
        tenderNumber: Value(
          _isHigherCourt ? _emptyToNull(_tenderNumberController.text) : null,
        ),
        previousCourtCase: Value(
          _isHigherCourt
              ? _emptyToNull(_previousCourtCaseController.text)
              : null,
        ),
        districtOfOrigin: Value(
          _isHigherCourt
              ? _emptyToNull(_districtOfOriginController.text)
              : null,
        ),
        petitioner: Value(_petitionerController.text.trim()),
        petitionerLeadCounsel: Value(
          _emptyToNull(_petitionerCounselController.text),
        ),
        respondent: Value(_respondentController.text.trim()),
        respondentLeadCounsel: Value(
          _emptyToNull(_respondentCounselController.text),
        ),
        onBehalfId: Value(onBehalf.id),
        partyPhone: Value(_completePartyPhone()),
        caseTitleAndSection: Value(_emptyToNull(_caseTitleController.text)),
        caseRemarks: Value(_emptyToNull(_caseRemarksController.text)),
        nextDate: Value(_nextDate!.millisecondsSinceEpoch),
        lastStep: Value(
          _selectedSteps.isEmpty
              ? null
              : _selectedSteps.map((item) => item.stepName).join(','),
        ),
        notesResults: Value(_emptyToNull(_noteController.text)),
        result: Value(
          _isHigherCourt ? _emptyToNull(_resultController.text) : null,
        ),
        updatedAt: Value(now),
      );
      final id = await formRepository.save(
        companion: companion,
        initialCase: widget.initialCase,
        userId: identity.getId(),
        notificationEnabled: _isNotificationEnabled,
        notificationOffsets: _selectedNotificationOffsets,
        notificationTimeMinutes: _notificationTimeMinutes,
        updatedAt: now,
      );
      // The save wrote this case's notification preference in the same
      // transaction, so ask for the premium preference push that carries it
      // to the account.
      ref.read(pushPreferencesProvider)();
      // Re-arm the alert alarms: this case may add a time slot or move one.
      await ref.read(notificationSchedulerProvider).syncSchedule();
      if (!mounted) return;
      // An edited hearing date offers the client a prepared message. Add mode
      // has no previous date, and the flow itself skips an unchanged day.
      final initialCase = widget.initialCase;
      if (initialCase != null) {
        await maybeSendAutomatedClientNotification(
          context,
          ref: ref,
          updatedCase: initialCase.copyWith(
            courtId: _selectedCourt!.id,
            caseType: _selectedCaseType!.name,
            caseNumber: _composeCaseNumber(),
            onBehalfId: onBehalf.id,
            partyPhone: Value(_completePartyPhone()),
            nextDate: Value(_nextDate!.millisecondsSinceEpoch),
            lastStep: Value(
              _selectedSteps.isEmpty
                  ? null
                  : _selectedSteps.map((item) => item.stepName).join(','),
            ),
          ),
          previousNextDateMs: initialCase.nextDate,
        );
      }
      if (!mounted) return;
      widget.onSave?.call();
      Navigator.of(context).pop(id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  String _composeCaseNumber() => _caseNumberController.text.trim();

  String? _completePartyPhone() {
    var digits = _partyPhoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    // The visible field is the portion after the immutable +88 prefix. Also
    // normalize pasted 88-prefixed input so it cannot become +8888....
    if (digits.startsWith('88')) digits = digits.substring(2);
    if (digits.isEmpty) return null;
    return '+88$digits';
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

/// Quick date/step/note update popup. The repository owns history creation.
class QuickUpdateCaseDialog extends ConsumerStatefulWidget {
  /// Creates the quick-update dialog.
  const QuickUpdateCaseDialog({
    required this.currentCase,
    this.canEdit = true,
    super.key,
  });

  /// Case being updated.
  final Case currentCase;

  /// Host permission hint; firm membership is checked against the local cache.
  final bool canEdit;

  /// Shows the popup and returns when the repository transaction completes.
  static Future<void> show(
    BuildContext context,
    Case currentCase, {
    bool canEdit = true,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          QuickUpdateCaseDialog(currentCase: currentCase, canEdit: canEdit),
    );
  }

  @override
  ConsumerState<QuickUpdateCaseDialog> createState() =>
      _QuickUpdateCaseDialogState();
}

class _QuickUpdateCaseDialogState extends ConsumerState<QuickUpdateCaseDialog> {
  final _noteController = TextEditingController();
  final _resultController = TextEditingController();
  DateTime? _currentNextDate;
  DateTime? _date;
  List<Step> _steps = const [];
  List<Step> _selectedSteps = const [];
  List<int> _notificationOffsets = const [];
  List<int> _selectedNotificationOffsets = const [];
  // The case's own alert time; null means it follows the Settings default.
  int? _notificationTimeMinutes;
  int _defaultNotificationTime = defaultNotificationMinutes;
  bool _isNotificationEnabled = true;
  bool _isHigherCourt = false;
  bool _loading = true;
  bool _saving = false;
  bool _permissionResolved = false;
  bool _canEdit = false;

  /// Court category of the case's court, used only to localize its case type.
  String? _courtCategoryId;

  @override
  void initState() {
    super.initState();
    _currentNextDate = widget.currentCase.nextDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(widget.currentCase.nextDate!);
    // Keep the editable field blank; the current value is shown only in the
    // read-only summary above it.
    _date = null;
    _noteController.text = widget.currentCase.notesResults ?? '';
    _resultController.text = widget.currentCase.result ?? '';
    _loadSteps();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadSteps() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final permissions = await ref.read(caseWritePermissionsProvider.future);
      final identity = ref.read(localIdentityServiceProvider);
      final preference = await CaseNotificationPreferencesDao(
        db,
      ).get(identity.getId(), widget.currentCase.id);
      // Day Offset mirrors Settings → Notifications when the case has no
      // preference row of its own.
      final settingsRepository = await ref.read(
        settingsRepositoryProvider.future,
      );
      final settings = await settingsRepository.getSettings();
      final court = await CourtsDao(db).getById(widget.currentCase.courtId);
      _courtCategoryId = court?.courtCategoryId;
      // AD/HCD courts have no steps; the update window shows Result instead.
      _isHigherCourt =
          court != null &&
          (court.courtCategoryId == appellateDivisionId ||
              court.courtCategoryId == highCourtDivisionId);
      final steps = court == null
          ? <Step>[]
          : await StepsDao(db).getByCategory(court.courtCategoryId);
      if (!mounted) return;
      setState(() {
        _steps = steps;
        final storedSteps = (widget.currentCase.lastStep ?? '')
            .split(',')
            .map((step) => step.trim())
            .where((step) => step.isNotEmpty)
            .toSet();
        _selectedSteps = steps
            .where(
              (item) =>
                  storedSteps.contains(item.id) ||
                  storedSteps.contains(item.stepName),
            )
            .toList(growable: false);
        _notificationOffsets = notificationDayOffsetOptions;
        _selectedNotificationOffsets = _decodeNotificationOffsets(
          preference?.offsets,
          fallback: settings.notificationDayOffset,
        );
        // The case's own choice if it has one, else the Settings default (the
        // same rule the alert planner applies).
        _isNotificationEnabled =
            preference?.enabled ?? settings.notificationEnabled;
        _notificationTimeMinutes = preference?.timeMinutes;
        _defaultNotificationTime =
            settings.notificationTime ?? defaultNotificationMinutes;
        _permissionResolved = true;
        _canEdit = permissions.canEdit;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissionResolved = true;
          _canEdit = false;
          _loading = false;
        });
      }
    }
  }

  List<int> _decodeNotificationOffsets(String? raw, {int? fallback}) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<num>()
              .map((value) => value.toInt())
              .toList();
        }
      } on FormatException {
        // Ignore malformed local preference data and use the default below.
      }
    }
    return fallback == null ? const [] : [fallback];
  }

  Future<void> _pickDate() async {
    final date = await showPlainDatePicker(
      context,
      initialDate: _date,
      styleActions: true,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  String _formatDate(BuildContext context, DateTime date) => DateFormat(
    'dd/MM/yy, EEE',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);

  Widget _quickUpdateNextDateAndNotificationRow(
    BuildContext context,
    bool editable,
  ) {
    final l = AppLocalizations.of(context);
    final dateText = _date == null ? '' : _formatDate(context, _date!);
    final emptyDateBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final filledDateBorder = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.addEditCaseSheet_nextDate, style: AppTypography.labelLg),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                key: const ValueKey('quick-update-next-date'),
                onTap: editable ? _pickDate : null,
                child: InputDecorator(
                  isEmpty: dateText.isEmpty,
                  decoration: InputDecoration(
                    enabled: editable,
                    fillColor: dateText.isEmpty
                        ? AppColors.surface
                        : AppColors.surfaceVariant,
                    enabledBorder: dateText.isEmpty
                        ? emptyDateBorder
                        : filledDateBorder,
                    focusedBorder: dateText.isEmpty
                        ? emptyDateBorder
                        : filledDateBorder,
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    dateText.isEmpty ? l.addEditCaseSheet_pickDate : dateText,
                    style: AppTypography.bodyMd.copyWith(
                      color: dateText.isEmpty
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Text(
                l.addEditCaseSheet_notification,
                style: AppTypography.labelMd,
              ),
              IconButton(
                key: const ValueKey('quick-update-notification'),
                tooltip: l.addEditCaseSheet_notification,
                onPressed: editable
                    ? () => setState(
                        () => _isNotificationEnabled = !_isNotificationEnabled,
                      )
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: _isNotificationEnabled
                      ? Colors.black
                      : Colors.transparent,
                  foregroundColor: _isNotificationEnabled
                      ? Colors.white
                      : Colors.black,
                  side: _isNotificationEnabled
                      ? null
                      : const BorderSide(color: Colors.black, width: 2),
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  _isNotificationEnabled
                      ? Icons.notifications
                      : Icons.notifications_none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickUpdateTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required Key fieldKey,
    required int maxLines,
    required bool enabled,
  }) {
    final isEmpty = controller.text.trim().isEmpty;
    final emptyOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final filledOutline = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final emptyFocusedOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    final filledFocusedOutline = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.secondary, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            fillColor: isEmpty ? AppColors.surface : AppColors.surfaceVariant,
            enabledBorder: isEmpty ? emptyOutline : filledOutline,
            focusedBorder: isEmpty ? emptyFocusedOutline : filledFocusedOutline,
          ),
        ),
      ],
    );
  }

  /// The case's Notification Time, the same control the Add/Edit Case form
  /// shows: the Settings default until the user picks its own.
  Widget _quickUpdateNotificationTimeField(
    BuildContext context,
    bool editable,
  ) {
    final l = AppLocalizations.of(context);
    final effective = _notificationTimeMinutes ?? _defaultNotificationTime;
    final isOverride = _notificationTimeMinutes != null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.settingsNotifications_timeLabel, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          key: const ValueKey('quick-update-notification-time'),
          onTap: editable ? () => _pickNotificationTime(effective) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              enabled: editable,
              fillColor: AppColors.surfaceVariant,
              enabledBorder: border,
              focusedBorder: border,
              suffixIcon: isOverride
                  ? IconButton(
                      key: const ValueKey(
                        'quick-update-notification-time-reset',
                      ),
                      tooltip: l.settingsViewSettings_fontSizeReset,
                      onPressed: editable
                          ? () =>
                                setState(() => _notificationTimeMinutes = null)
                          : null,
                      icon: const Icon(Icons.restart_alt),
                    )
                  : const Icon(Icons.schedule),
            ),
            child: Text(
              AppDateUtils.formatClockTime(
                effective,
                locale: Localizations.localeOf(context).languageCode,
              ),
              style: AppTypography.bodyMd,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickNotificationTime(int initialMinutes) async {
    final picked = await showNotificationTimePicker(
      context,
      initialMinutes: initialMinutes,
    );
    if (picked == null || !mounted) return;
    setState(() => _notificationTimeMinutes = picked.hour * 60 + picked.minute);
  }

  /// Opens the same day-offset window Settings → Notifications uses.
  Future<void> _pickNotificationOffsets(BuildContext context) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsMultiSelectDialog<int>(
        title: l.settingsNotifications_selectDayOffsetTitle,
        order: _notificationOffsets,
        selected: _selectedNotificationOffsets.toSet(),
        labelOf: (offset) => _offsetLabel(context, offset),
        popoverWindow: true,
        minSelected: 1,
        minSelectedMessage: l.settingsNotifications_keepOneOffset,
        onChanged: (_, chosen) =>
            setState(() => _selectedNotificationOffsets = chosen),
      ),
    );
  }

  String _offsetLabel(BuildContext context, int offset) {
    final l = AppLocalizations.of(context);
    return offset == 0
        ? l.addEditCaseSheet_offsetSameDay
        : offset == 1
        ? l.addEditCaseSheet_offsetDayBefore
        : l.addEditCaseSheet_offsetDaysBefore(offset);
  }

  Future<void> _commit() async {
    if (_saving || !widget.canEdit || !_permissionResolved || !_canEdit) {
      return;
    }
    setState(() => _saving = true);
    try {
      final db = await ref.read(databaseProvider.future);
      final repository = await ref.read(
        transactionalCaseRepositoryProvider.future,
      );
      final identity = ref.read(localIdentityServiceProvider);
      // The quick update is a write on a case like any other, so it meets the
      // same allowance boundary as the full form.
      final premium = await resolvePremiumAccess(db, identity.getId());
      final allowance = await resolveWriteAllowance(
        db,
        tier: ref.read(allowanceTierProvider),
        premium: premium,
      );
      if (!allowance.isCaseWritable(widget.currentCase.id)) {
        if (mounted) {
          setState(() => _saving = false);
          showReadOnlyWriteMessage(
            context,
            AppLocalizations.of(context).lapse_readOnlyCase,
          );
        }
        return;
      }
      final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db.transaction(() async {
        await repository.updateCaseInTransaction(
          CasesCompanion(
            id: Value(widget.currentCase.id),
            // An untouched blank field preserves the current stored date.
            nextDate: Value(
              _date?.millisecondsSinceEpoch ?? widget.currentCase.nextDate,
            ),
            lastStep: Value(
              _selectedSteps.isEmpty
                  ? null
                  : _selectedSteps.map((item) => item.stepName).join(','),
            ),
            notesResults: Value(
              _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
            result: Value(
              _isHigherCourt
                  ? (_resultController.text.trim().isEmpty
                        ? null
                        : _resultController.text.trim())
                  : null,
            ),
          ),
          baseCase: widget.currentCase,
          isQuickUpdate: true,
        );
        await CaseNotificationPreferencesDao(db).upsert(
          CaseNotificationPreferencesCompanion(
            userId: Value(identity.getId()),
            caseId: Value(widget.currentCase.id),
            enabled: Value(_isNotificationEnabled),
            offsets: Value(jsonEncode(_selectedNotificationOffsets)),
            timeMinutes: Value(_notificationTimeMinutes),
            updatedAt: Value(updatedAt),
          ),
        );
      });
      // The quick update wrote this case's notification preference; ask for
      // the premium preference push that carries it to the account.
      ref.read(pushPreferencesProvider)();
      // Re-arm the alert alarms: this update may add a time slot or move one.
      await ref.read(notificationSchedulerProvider).syncSchedule();
      if (!mounted) return;
      // A moved hearing date offers the client a prepared message; the date is
      // compared with the row's own value, and the message never blocks a save.
      await maybeSendAutomatedClientNotification(
        context,
        ref: ref,
        updatedCase: widget.currentCase.copyWith(
          nextDate: Value(
            _date?.millisecondsSinceEpoch ?? widget.currentCase.nextDate,
          ),
          lastStep: Value(
            _selectedSteps.isEmpty
                ? null
                : _selectedSteps.map((item) => item.stepName).join(','),
          ),
        ),
        previousNextDateMs: widget.currentCase.nextDate,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editable =
        widget.canEdit && _permissionResolved && _canEdit && !_saving;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      // The same 8 px window corner as the Select Day Offset window.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
        color: AppColors.surfaceContainerLowest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The title band is the app's black (#000000) — the same black the
              // buttons and the side menu wear — rather than the ink navy the
              // headers otherwise use (user request).
              Container(
                key: const ValueKey('quick-update-title'),
                color: AppColors.secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        l.sharedActions_update,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLg.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.onPrimary,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${context.l10n.caseTypeLabel(widget.currentCase.caseType, courtCategoryId: _courtCategoryId)} ${widget.currentCase.caseNumber}',
                                key: const ValueKey('quick-update-case-number'),
                                style: AppTypography.titleLg.copyWith(
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${l.quickUpdateCase_currentNextDate}: ${_currentNextDate == null ? l.customDropdown_selectOption : _formatDate(context, _currentNextDate!)}',
                                key: const ValueKey(
                                  'quick-update-current-next-date',
                                ),
                                style: AppTypography.bodySm,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        // Keep the current-case summary visually separate from
                        // the editable schedule fields below it.
                        const SizedBox(height: AppSpacing.lg),
                        _quickUpdateNextDateAndNotificationRow(
                          context,
                          editable,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Day Offset and Notification Time share one line, as
                        // they do on the Add/Edit Case form.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CustomDropdown<int>(
                                fieldKey: const ValueKey(
                                  'quick-update-day-offset',
                                ),
                                label: l.addEditCaseSheet_dayOffset,
                                items: _notificationOffsets,
                                selectedValues: _selectedNotificationOffsets,
                                multiSelect: true,
                                searchable: false,
                                itemLabel: (item) =>
                                    _offsetLabel(context, item),
                                enabled: editable,
                                emptyFillColor: AppColors.surface,
                                selectedFillColor: AppColors.surfaceVariant,
                                outlined: true,
                                // The same window Settings → Notifications
                                // uses.
                                onOpenPicker: () =>
                                    _pickNotificationOffsets(context),
                                onMultiChanged: (values) => setState(
                                  () => _selectedNotificationOffsets = values,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _quickUpdateNotificationTimeField(
                                context,
                                editable,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_isHigherCourt)
                          _quickUpdateTextField(
                            context,
                            label: l.addEditCaseSheet_result,
                            controller: _resultController,
                            fieldKey: const ValueKey('quick-update-result'),
                            maxLines: 3,
                            enabled: editable,
                          )
                        else
                          CustomDropdown<Step>(
                            fieldKey: const ValueKey('quick-update-step'),
                            label: l.addEditCaseSheet_step,
                            items: _steps,
                            selectedValues: _selectedSteps,
                            multiSelect: true,
                            itemLabel: (item) =>
                                _seedLabel(context, item.id, item.stepName),
                            enabled: editable,
                            emptyFillColor: AppColors.surface,
                            selectedFillColor: AppColors.surfaceVariant,
                            outlined: true,
                            onMultiChanged: (values) =>
                                setState(() => _selectedSteps = values),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        _quickUpdateTextField(
                          context,
                          label: l.addEditCaseSheet_note,
                          controller: _noteController,
                          fieldKey: const ValueKey('quick-update-note'),
                          maxLines: 4,
                          enabled: editable,
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _loading || !editable ? null : _commit,
                    child: Text(l.sharedActions_save),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('add-edit-header'),
    color: Colors.black,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md * .7,
    ),
    child: Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleLg.copyWith(color: AppColors.onPrimary),
          ),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          color: AppColors.onPrimary,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _SheetFooter extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  const _SheetFooter({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('add-edit-footer'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border(top: BorderSide(color: AppColors.outlineVariant)),
    ),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const ValueKey('add-edit-save'),
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      ),
    ),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
