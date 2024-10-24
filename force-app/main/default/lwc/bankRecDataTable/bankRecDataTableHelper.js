import { LabelService } from "c/utils";
import Labels from "./labels";
export default class BankRecDataTableHelper {

  static getColumns() {
    let inst = new BankRecDataTableHelper();
    return inst.main_columns;
  }

  static getColumnsWithLedgerAmount() {
    let inst = new BankRecDataTableHelper();
    inst.main_columns.splice(4, 0, inst.ledgerAmountColumn)
    return inst.main_columns;
  }

  static getClearedWarningMessageTemplate() {
    return BankRecDataTableHelper.CLEARED_WARNING_MESSAGE_TEMPLATE;
  }

  static getVoidedWarningMessage() {
    return BankRecDataTableHelper.VOIDED_WARNING_MESSAGE;
  }

  static getLegacyBDWarningMessage() {
    return BankRecDataTableHelper.LEGACY_BD_WARNING_MESSAGE;
  }

  static getLimitErrorMessage() {
    return BankRecDataTableHelper.LIMIT_ERROR_MESSAGE;
  }

  main_columns = [
    { label: LabelService.commonCleared, type: 'button-icon', initialWidth: 90,
      cellAttributes: {
        class: { fieldName: 'selectedRow' }
      },
      typeAttributes: {
        name: 'cleared',
        class: { fieldName: 'clearedIcon' },
        title: { fieldName: 'clearedTitle' },
        variant: 'bare',
        size: 'medium',
        iconName: {fieldName: 'clearedButtonIcon'},
        disabled: {fieldName :'disableClearedButton'}
      }
    },
    { label: LabelService.commonDate,
      fieldName: 'recordDate',
      type: 'customDate',
      sortable: true,
      initialWidth: 120,
      typeAttributes: {
        label: {fieldName: 'recordDate'},
        target: self},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
        },
    { label: Labels.INF_BANK_TRANSACTION_DATE,
      fieldName: 'clearedDate',
      type: 'button',
      sortable: true,
      initialWidth: 140,
      typeAttributes: {
        name: 'clearedDate',
        label: {fieldName: 'clearedDate'},
        variant: 'base',
        size: 'medium',
        disabled: {fieldName :'disableClearedDateButton'}},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
    },
    {
      label: LabelService.commonAmount,
      fieldName: 'amount',
      type: 'customCurrency',
      sortable: true,
      initialWidth: 200,
      cellAttributes: {
        class: { fieldName: 'selectedRow' },
        alignment: 'right'},
      typeAttributes: {
        valueStyle: {fieldName: 'amountStyle'},
        currencyCode: {fieldName: 'currency'},
        isMultiCurrencyEnabled: {fieldName: 'isMultiCurrencyEnabled'}},
    },
    { label: Labels.INF_SOURCE_LINK, fieldName: 'typeLink', type: 'url', sortable: true, initialWidth: 130,
      typeAttributes: {
        label: {fieldName: 'typeName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
    },
    { label: LabelService.commonType, fieldName: 'type', type: 'text', sortable: true, initialWidth: 100,
      typeAttributes: {
        label: {fieldName: 'type'}},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
    },
    { label: Labels.INF_REF, fieldName: 'reference', type: 'text', sortable: true,
      typeAttributes: {
        label: {fieldName: 'reference'},
        target: self},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
    },
    { label: LabelService.commonPayee, fieldName: 'payeeLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'payeeName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
    },
    { label: LabelService.commonDescription, fieldName: 'description', type: 'text', sortable: true,
      typeAttributes: {
        label: {fieldName: 'description'},
        target: self},
      cellAttributes: {
        alignment: 'left',
        class: { fieldName: 'selectedRow' }}
    }
  ]

  ledgerAmountColumn = {
    label: Labels.INF_LEDGER_AMOUNT,
    fieldName: 'ledgerAmount',
    type: 'customCurrency',
    sortable: true,
    initialWidth: 200,
    cellAttributes: {
      class: { fieldName: 'selectedRow' },
      alignment: 'right'},
    typeAttributes: {
      valueStyle: {fieldName: 'amountStyle'},
      currencyCode: {fieldName: 'ledgerCurrency'},
      isMultiCurrencyEnabled: {fieldName: 'isMultiCurrencyEnabled'}},
  }

  static CLEARED_WARNING_MESSAGE_TEMPLATE = Labels.WRN_CLEARED_MESSAGE_TEMPLATE_RECONCILITION;

  static VOIDED_WARNING_MESSAGE = Labels.WRN_TRANSACTION_VOIDED_RECONCILITION;

  static LEGACY_BD_WARNING_MESSAGE = Labels.WRN_LEGACY_BD_MESSAGE;

  static LIMIT_ERROR_MESSAGE = ' '+ Labels.ERR_BANK_RECONCILIATION_LIMIT_EXCEEDED;

}