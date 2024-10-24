import Labels from "./labels";
import { LabelService } from "c/utils";

export default class FinReporterLedgerInquiryTableHelper {
  static getColumns() {
    let inst = new FinReporterLedgerInquiryTableHelper();
    return inst.main_columns;
  }

  main_columns = [
    { label: Labels.INF_TRANSACTION_ID, fieldName: 'transactionLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'transactionName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonDate,
      fieldName: 'recordDate',
      type: 'date',
      sortable: true,
      typeAttributes: {
        label: {fieldName: 'recordDate'},
        month: '2-digit',
        day: '2-digit',
        year: 'numeric',
        target: self}
    },
    { label: LabelService.commonGLAccount, fieldName: 'glAccountLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'glAccountName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonAccount, fieldName: 'accountLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'accountName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonSource, fieldName: 'sourceLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'sourceName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonAccountingPeriod, fieldName: 'periodLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'periodName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonProject, fieldName: 'projectLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'projectName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonProjectTask, fieldName: 'projectTaskLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'projectTaskName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: LabelService.commonProduct, fieldName: 'productLink', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'productName'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: `${LabelService.commonGLVariable} 1`, fieldName: 'glav1Link', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'glav1Name'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: `${LabelService.commonGLVariable} 2`, fieldName: 'glav2Link', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'glav2Name'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: `${LabelService.commonGLVariable} 3`, fieldName: 'glav3Link', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'glav3Name'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    { label: `${LabelService.commonGLVariable} 4`, fieldName: 'glav4Link', type: 'url', sortable: true,
      typeAttributes: {
        label: {fieldName: 'glav4Name'},
        target: '_blank'},
      cellAttributes: {
        alignment: 'left'}
    },
    {
      label: LabelService.commonTotalAmount,
      fieldName: 'totalAmount',
      type: 'customCurrency',
      sortable: true,
      cellAttributes: {
        class: 'slds-text-align_right'},
      typeAttributes: {
        valueStyle: {fieldName: 'amountStyle'},
        valueParentheses: {fieldName: 'negativeAmount'},
        valueHideIsoCode: true,
        currencyCode: {fieldName: 'currency'},
        isMultiCurrencyEnabled: {fieldName: 'isMultiCurrencyEnabled'}},
    },
    {
      label: LabelService.commonRunningBalance,
      fieldName: 'balance',
      type: 'customCurrency',
      cellAttributes: {
        class: 'slds-text-align_right'},
      typeAttributes: {
        valueStyle: {fieldName: 'balanceAmountStyle'},
        valueParentheses: {fieldName: 'negativeBalanceAmount'},
        valueHideIsoCode: true,
        currencyCode: {fieldName: 'currency'},
        isMultiCurrencyEnabled: {fieldName: 'isMultiCurrencyEnabled'}},
    }
  ]

}