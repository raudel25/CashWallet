import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('es')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String translate(String key, {Map<String, String>? params}) {
    final languageCode =
        supportedLocales
            .map((locale) => locale.languageCode)
            .contains(locale.languageCode)
        ? locale.languageCode
        : 'en';
    final values = _localizedValues[languageCode] ?? _localizedValues['en']!;
    String value = values[key] ?? _localizedValues['en']![key] ?? key;
    params?.forEach((paramKey, paramValue) {
      value = value.replaceAll('{$paramKey}', paramValue);
    });
    return value;
  }

  String rangeLabel(DashboardRangeLabel range) {
    switch (range) {
      case DashboardRangeLabel.day:
        return translate('range_day');
      case DashboardRangeLabel.week:
        return translate('range_week');
      case DashboardRangeLabel.month:
        return translate('range_month');
    }
  }

  String languageName(String code) {
    switch (code) {
      case 'es':
        return translate('language_spanish');
      case 'en':
      default:
        return translate('language_english');
    }
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Cash Wallet',
      'tab_home': 'Home',
      'tab_history': 'History',
      'tab_settings': 'Settings',
      'home_register_movement': 'Register movement',
      'home_new_income': 'New income',
      'home_new_expense': 'New expense',
      'home_edit_income': 'Edit income',
      'home_edit_expense': 'Edit expense',
      'home_configure_denominations':
          'Set up your denominations in settings first.',
      'home_income_positive': 'Income must be greater than zero.',
      'home_income_saved': 'Income saved successfully.',
      'home_no_cash_for_expense':
          'You have no cash available to record an expense.',
      'home_expense_positive': 'Expense must be greater than zero.',
      'home_expense_saved': 'Expense saved successfully.',
      'home_select_currency': 'Select the currency to use',
      'home_select_language': 'Select the language',
      'home_income_instruction':
          'Indicate how many units of each denomination you will store.',
      'home_expense_instruction':
          'Indicate how many units of each denomination you will use.',
      'home_description_label': 'Description',
      'home_description_income_hint': 'e.g. Savings, sale, etc.',
      'home_description_expense_hint': 'e.g. Purchase, bill, etc.',
      'home_total_calculated': 'Calculated total',
      'home_save_income': 'Save income',
      'home_need_income_units': 'Add at least one unit to save the income.',
      'home_save_expense': 'Save expense',
      'home_need_expense_units': 'Indicate which denominations you are using.',
      'home_only_have_units': 'You only have {count} units of {value}.',
      'form_date_label': 'Date and time',
      'form_available_hint': 'Available: {count}',
      'settings_title': 'Settings',
      'settings_description': 'Select an item to customize your experience.',
      'settings_currency': 'Currency',
      'settings_language': 'Language',
      'settings_denominations': 'Denominations',
      'settings_currency_subtitle': '{name} ({code})',
      'settings_language_subtitle': '{language}',
      'settings_denominations_subtitle': 'Manage your bills in {currency}.',
      'settings_theme': 'Theme',
      'settings_theme_subtitle': '{theme}',
      'settings_backup': 'Backup',
      'settings_backup_subtitle': 'Export or restore your data',
      'settings_export': 'Export data',
      'settings_import': 'Import data',
      'settings_import_confirm_title': 'Restore from backup',
      'settings_import_confirm_msg':
          'This will replace ALL current data with the contents of the selected file. Do you want to continue?',
      'settings_import_success': 'Data restored successfully.',
      'settings_import_failed': 'Could not import the backup file.',
      'settings_export_failed': 'Export failed.',
      'theme_system': 'System',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'denominations_title': 'Denominations ({currency})',
      'denominations_intro':
          'Add each cash denomination ({currency}) you have stored.',
      'denominations_dialog_title': 'New denomination',
      'denominations_amount_label': 'Amount',
      'denominations_amount_invalid': 'Enter a valid amount',
      'denominations_amount_gt_zero': 'Amount must be greater than zero',
      'common_cancel': 'Cancel',
      'common_save': 'Save',
      'common_continue': 'Continue',
      'common_delete': 'Delete',
      'denominations_exists': 'This denomination is already registered.',
      'denominations_remove_error':
          'You cannot delete {value} because you still have {count} units.',
      'denominations_saved_label': 'Saved denomination',
      'denominations_empty_title': 'You have not added denominations yet.',
      'denominations_empty_subtitle': 'Use the "Add" button to start.',
      'denominations_add': 'Add',
      'dashboard_total_balance_title': 'Total balance ({currency})',
      'dashboard_summary': 'Summary by {range}',
      'dashboard_incomes': 'Incomes',
      'dashboard_expenses': 'Expenses',
      'dashboard_net_current': 'Current net',
      'dashboard_no_change': 'No changes',
      'dashboard_comparison': '{prefix} {amount} compared to previous period',
      'dashboard_comparison_short': 'vs. previous period',
      'dashboard_prefix_up': 'Up',
      'dashboard_prefix_down': 'Down',
      'dashboard_denominations_title': 'Bills by denomination',
      'dashboard_denominations_empty':
          'You have no denominations with balance yet.',
      'dashboard_total_label': 'Total',
      'dashboard_trend_title': 'Activity by {range}',
      'dashboard_trend_empty': 'No activity in this period.',
      'dashboard_units_count': '{count} units',
      'history_title': 'Review each recorded transaction.',
      'history_empty_incomes_title': 'You have no registered incomes',
      'history_empty_incomes_desc': 'Record your incomes from the home screen.',
      'history_empty_expenses_title': 'You have no registered expenses',
      'history_empty_expenses_desc':
          'Record your expenses from the home screen.',
      'history_no_description': 'No description',
      'history_no_breakdown': 'No breakdown',
      'history_breakdown': 'Breakdown: {breakdown}',
      'history_confirm_delete_title': 'Delete entry',
      'history_confirm_delete_msg':
          'Are you sure you want to delete this entry? This action cannot be undone.',
      'history_search_hint': 'Search by description or amount…',
      'history_filter_date': 'Filter by date',
      'history_clear_filters': 'Clear filters',
      'history_no_results_title': 'No results',
      'history_no_results_desc': 'Try clearing your filters.',
      'history_edit': 'Edit',
      'history_entry_deleted': 'Entry deleted.',
      'history_entry_updated': 'Entry updated.',
      'denominations_confirm_delete_title': 'Delete denomination',
      'denominations_confirm_delete_msg':
          'Are you sure you want to delete this denomination?',
      'language_spanish': 'Spanish',
      'language_english': 'English',
      'range_day': 'Day',
      'range_week': 'Week',
      'range_month': 'Month',
      'history_filter_incomes': 'Incomes',
      'history_filter_expenses': 'Expenses',
      'common_units': 'units',
      'common_amount_prefix': '{symbol} {value}',
      'common_add': 'Add',
      'dashboard_currency_name': '{name}',

      // Security
      'security_title': 'Security',
      'security_subtitle': 'Manage your app security settings',
      'security_pin': 'PIN',
      'security_pin_min': 'PIN must be at least 6 digits',
      'security_pin_set': 'PIN is set',
      'security_pin_not_set': 'No PIN set',
      'security_set_pin': 'Set PIN',
      'security_confirm': 'Confirm',
      'security_confirm_match': 'Values do not match',
      'security_password': 'Password',
      'security_password_set': 'Password is set',
      'security_password_not_set': 'No password set',
      'security_set_password': 'Set password',
      'security_password_min': 'Password must be at least 6 characters',
      'security_remove': 'Remove',
      'security_set': 'Set',
      'security_biometric': 'Biometric unlock',
      'security_biometric_desc': 'Use device biometrics to unlock the app',
      'security_biometric_unavailable':
          'Biometrics not available on this device',
      'security_biometric_verify': 'Please verify your identity',
      'security_biometric_failed': 'Biometric verification failed.',
      'security_biometric_error': 'An error occurred during authentication.',
      'security_unlock_title': 'Unlock',
      'security_biometric_prompt': 'Use biometrics or enter your credentials',
      'security_unlock': 'Unlock',
      'security_invalid_pin': 'Invalid PIN',
      'security_invalid_password': 'Invalid password',
      'security_confirm_remove_password_title': 'Warning',
      'security_confirm_remove_password_msg':
          'Setting a PIN will remove the existing password. Do you want to continue?',
      'security_confirm_remove_pin_title': 'Warning',
      'security_confirm_remove_pin_msg':
          'Setting a password will remove the existing PIN. Do you want to continue?',
      'security_biometric_requires_credential':
          'Enable a PIN or password before enabling biometrics.',
      'security_locked_title': 'Too many attempts',
      'security_locked_msg': 'Try again in {seconds} seconds.',
      'security_attempts_remaining': '{count} attempts remaining.',
      'security_auto_lock': 'Auto-lock',
      'security_auto_lock_desc':
          'Require authentication after a period of inactivity',
      'security_auto_lock_immediately': 'Immediately',
      'security_auto_lock_minutes': '{minutes} minutes',
      'security_auto_lock_never': 'Never',
    },
    'es': {
      'app_title': 'Cash Wallet',
      'tab_home': 'Inicio',
      'tab_history': 'Historial',
      'tab_settings': 'Configuración',
      'home_register_movement': 'Registrar movimiento',
      'home_new_income': 'Nuevo ingreso',
      'home_new_expense': 'Nuevo gasto',
      'home_edit_income': 'Editar ingreso',
      'home_edit_expense': 'Editar gasto',
      'home_configure_denominations':
          'Primero configura tus denominaciones en ajustes.',
      'home_income_positive': 'El ingreso debe ser mayor que cero.',
      'home_income_saved': 'Ingreso registrado correctamente.',
      'home_no_cash_for_expense':
          'No tienes efectivo disponible para registrar un gasto.',
      'home_expense_positive': 'El gasto debe ser mayor que cero.',
      'home_expense_saved': 'Gasto registrado correctamente.',
      'home_select_currency': 'Selecciona la moneda a usar',
      'home_select_language': 'Selecciona el idioma',
      'home_income_instruction':
          'Indica cuántas unidades de cada denominación vas a guardar.',
      'home_expense_instruction':
          'Indica cuántas unidades de cada denominación vas a usar.',
      'home_description_label': 'Descripción',
      'home_description_income_hint': 'Ej. Ahorros, venta, etc.',
      'home_description_expense_hint': 'Ej. Compra, pago de servicio, etc.',
      'home_total_calculated': 'Total calculado',
      'home_save_income': 'Guardar ingreso',
      'home_need_income_units':
          'Agrega al menos una unidad para guardar el ingreso.',
      'home_save_expense': 'Guardar gasto',
      'home_need_expense_units': 'Indica qué denominaciones estás usando.',
      'home_only_have_units': 'Solo tienes {count} unidades de {value}.',
      'form_date_label': 'Fecha y hora',
      'form_available_hint': 'Disponible: {count}',
      'settings_title': 'Configuración',
      'settings_description':
          'Selecciona un apartado para personalizar tu experiencia.',
      'settings_currency': 'Moneda',
      'settings_language': 'Idioma',
      'settings_denominations': 'Denominaciones',
      'settings_currency_subtitle': '{name} ({code})',
      'settings_language_subtitle': '{language}',
      'settings_denominations_subtitle':
          'Administra tus billetes en {currency}.',
      'settings_theme': 'Tema',
      'settings_theme_subtitle': '{theme}',
      'settings_backup': 'Respaldo',
      'settings_backup_subtitle': 'Exporta o restaura tus datos',
      'settings_export': 'Exportar datos',
      'settings_import': 'Importar datos',
      'settings_import_confirm_title': 'Restaurar respaldo',
      'settings_import_confirm_msg':
          'Esto reemplazará TODOS los datos actuales con el contenido del archivo seleccionado. ¿Quieres continuar?',
      'settings_import_success': 'Datos restaurados correctamente.',
      'settings_import_failed': 'No se pudo importar el archivo de respaldo.',
      'settings_export_failed': 'No se pudo exportar.',
      'theme_system': 'Sistema',
      'theme_light': 'Claro',
      'theme_dark': 'Oscuro',
      'denominations_title': 'Denominaciones ({currency})',
      'denominations_intro':
          'Agrega cada una de las denominaciones de efectivo ({currency}) que tienes guardadas.',
      'denominations_dialog_title': 'Nueva denominación',
      'denominations_amount_label': 'Monto',
      'denominations_amount_invalid': 'Ingresa un monto válido',
      'denominations_amount_gt_zero': 'El monto debe ser mayor que cero',
      'common_cancel': 'Cancelar',
      'common_save': 'Guardar',
      'common_continue': 'Continuar',
      'common_delete': 'Eliminar',
      'denominations_exists': 'Esta denominación ya está registrada.',
      'denominations_remove_error':
          'No puedes eliminar {value} porque aún tienes {count} unidades.',
      'denominations_saved_label': 'Denominación guardada',
      'denominations_empty_title': 'Todavía no has añadido denominaciones.',
      'denominations_empty_subtitle': 'Utiliza el botón "Añadir" para empezar.',
      'denominations_add': 'Añadir',
      'dashboard_total_balance_title': 'Saldo total ({currency})',
      'dashboard_summary': 'Resumen por {range}',
      'dashboard_incomes': 'Ingresos',
      'dashboard_expenses': 'Gastos',
      'dashboard_net_current': 'Neto actual',
      'dashboard_no_change': 'Sin cambios',
      'dashboard_comparison': '{prefix} {amount} respecto al periodo anterior',
      'dashboard_comparison_short': 'vs. periodo anterior',
      'dashboard_prefix_up': 'Arriba',
      'dashboard_prefix_down': 'Abajo',
      'dashboard_denominations_title': 'Unidades por denominación',
      'dashboard_denominations_empty':
          'Aún no tienes denominaciones con saldo.',
      'dashboard_total_label': 'Total',
      'dashboard_trend_title': 'Actividad por {range}',
      'dashboard_trend_empty': 'Sin actividad en este periodo.',
      'dashboard_units_count': '{count} unidades',
      'history_title': 'Consulta cada movimiento registrado.',
      'history_empty_incomes_title': 'No tienes ingresos registrados',
      'history_empty_incomes_desc':
          'Registra tus ingresos desde la pantalla de inicio.',
      'history_empty_expenses_title': 'No tienes gastos registrados',
      'history_empty_expenses_desc':
          'Registra tus gastos desde la pantalla de inicio.',
      'history_no_description': 'Sin descripción',
      'history_no_breakdown': 'Sin desglose',
      'history_breakdown': 'Desglose: {breakdown}',
      'history_confirm_delete_title': 'Eliminar movimiento',
      'history_confirm_delete_msg':
          '¿Seguro que deseas eliminar este movimiento? Esta acción no se puede deshacer.',
      'history_search_hint': 'Buscar por descripción o monto…',
      'history_filter_date': 'Filtrar por fecha',
      'history_clear_filters': 'Limpiar filtros',
      'history_no_results_title': 'Sin resultados',
      'history_no_results_desc': 'Prueba a limpiar los filtros.',
      'history_edit': 'Editar',
      'history_entry_deleted': 'Movimiento eliminado.',
      'history_entry_updated': 'Movimiento actualizado.',
      'denominations_confirm_delete_title': 'Eliminar denominación',
      'denominations_confirm_delete_msg':
          '¿Seguro que deseas eliminar esta denominación?',
      'language_spanish': 'Español',
      'language_english': 'Inglés',
      'range_day': 'Día',
      'range_week': 'Semana',
      'range_month': 'Mes',
      'history_filter_incomes': 'Ingresos',
      'history_filter_expenses': 'Gastos',
      'common_units': 'unidades',
      'common_add': 'Añadir',
      'dashboard_currency_name': '{name}',

      // Seguridad
      'security_title': 'Seguridad',
      'security_subtitle': 'Administra la configuración de seguridad de la app',
      'security_pin': 'PIN',
      'security_pin_min': 'El PIN debe tener al menos 6 dígitos',
      'security_pin_set': 'PIN establecido',
      'security_pin_not_set': 'No hay PIN establecido',
      'security_set_pin': 'Establecer PIN',
      'security_confirm': 'Confirmar',
      'security_confirm_match': 'Los valores no coinciden',
      'security_password': 'Contraseña',
      'security_password_set': 'Contraseña establecida',
      'security_password_not_set': 'No hay contraseña establecida',
      'security_set_password': 'Establecer contraseña',
      'security_password_min': 'La contraseña debe tener al menos 6 caracteres',
      'security_remove': 'Eliminar',
      'security_set': 'Establecer',
      'security_biometric': 'Desbloqueo biométrico',
      'security_biometric_desc':
          'Usa la biometría del dispositivo para desbloquear la app',
      'security_biometric_unavailable':
          'Biometría no disponible en este dispositivo',
      'security_biometric_verify': 'Por favor verifica tu identidad',
      'security_biometric_failed': 'No se pudo verificar la biometría.',
      'security_biometric_error': 'Ocurrió un error durante la autenticación.',
      'security_unlock_title': 'Desbloquear',
      'security_biometric_prompt': 'Usa biometría o introduce tus credenciales',
      'security_unlock': 'Desbloquear',
      'security_invalid_pin': 'PIN inválido',
      'security_invalid_password': 'Contraseña inválida',
      'security_confirm_remove_password_title': 'Advertencia',
      'security_confirm_remove_password_msg':
          'Al establecer un PIN se eliminará la contraseña existente. ¿Deseas continuar?',
      'security_confirm_remove_pin_title': 'Advertencia',
      'security_confirm_remove_pin_msg':
          'Al establecer una contraseña se eliminará el PIN existente. ¿Deseas continuar?',
      'security_biometric_requires_credential':
          'Activa un PIN o contraseña antes de habilitar la biometría.',
      'security_locked_title': 'Demasiados intentos',
      'security_locked_msg': 'Inténtalo de nuevo en {seconds} segundos.',
      'security_attempts_remaining': 'Te quedan {count} intentos.',
      'security_auto_lock': 'Bloqueo automático',
      'security_auto_lock_desc':
          'Solicita autenticación tras un periodo de inactividad',
      'security_auto_lock_immediately': 'De inmediato',
      'security_auto_lock_minutes': '{minutes} minutos',
      'security_auto_lock_never': 'Nunca',
    },
  };
}

enum DashboardRangeLabel { day, week, month }

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .map((supported) => supported.languageCode)
      .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this);
  String t(String key, {Map<String, String>? params}) =>
      loc.translate(key, params: params);
}
