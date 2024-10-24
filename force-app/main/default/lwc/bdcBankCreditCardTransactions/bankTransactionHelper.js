import { keywords } from 'c/lookupKeywords';
import Labels from "./labels";
import { LabelService } from "c/utils";

export default class Helper {

  static getUnmatchedMainColumns() {
    return Helper.UNMATCHED_MAIN_COLUMNS;
  }

  static getUnmatchedAdditionalColumns() {
    return Helper.UNMATCHED_ADDITIONAL_COLUMNS;
  }

  static getTransactionMainColumns() {
    return Helper.TRANSACTION_MAIN_COLUMNS;
  }

  static getTransactionAdditionalColumns() {
    return Helper.TRANSACTION_ADDITIONAL_COLUMNS;
  }

  static UNMATCHED_MAIN_COLUMNS = [
    {
      label: LabelService.commonActions,
      fieldName: 'unmatchedActionName',
      variant: 'label-hidden',
      type: 'button',
      typeAttributes: {state: 'actionDisabled'}
    },{
      label: LabelService.commonDate,
      fieldName: 'bt.obj.AcctSeed__Date__c',
      type: 'date',
      sortable: true
    },{
      label: LabelService.commonAccount,
      fieldName: {
        AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Vendor__c',
        AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Account__c',
        AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__Account__c'
      },
      variant: 'label-hidden',
      type: 'lookupPreview',
      style: 'min-width:150px',
      typeAttributes: {
        fieldApiName: 'Name',
        recordApiName: 'proxyObj.sobjType',
        innerRecordApiName: 'Account',
        recordId: {
          AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Vendor__c',
          AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Account__c',
          AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__Account__c'
        }}
    },{
      label: LabelService.commonDescription,
      fieldName: 'bt.obj.AcctSeed__Description__c',
      variant: 'label-hidden',
      sortable: true,
      type: 'text',
      typeAttributes: {fieldApiName: 'AcctSeed__Description__c', recordApiName: 'bt.sobjType'}
    },{
      label: LabelService.commonGLAccount,
      fieldName: {
        AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Debit_GL_Account__c',
        AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Credit_GL_Account__c',
        AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__GL_Account__c'
      },
      variant: 'label-hidden',
      type: 'lookupPreview',
      typeAttributes: {
        fieldApiName: 'Name',
        recordApiName: 'proxyObj.sobjType',
        innerRecordApiName: 'AcctSeed__GL_Account__c',
        recordId: {
          AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Debit_GL_Account__c',
          AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Credit_GL_Account__c',
          AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__GL_Account__c'
        }}
    },{
      label: LabelService.commonType,
      value: 'selectedType',
      fieldName: 'selectedType',
      variant: 'label-hidden',
      style: 'width:160px',
      sortable: true,
      type: 'text'
    },{
      label: LabelService.commonAmount,
      fieldName: 'bt.obj.AcctSeed__Amount__c',
      type: 'currency',
      sortable: true,
      typeAttributes: {
        isMultiCurrencyEnabled: 'bt.isMultiCurrencyEnabled',
        currencyCode: 'bt.currencyIsoCode',
        style: 'amountStyle.valueStyle',
        parentheses: 'amountStyle.valueParentheses'
        }
    },{
      label: LabelService.commonDetails,
      fieldName: 'details',
      variant: 'label-hidden',
      type: 'combined',
      typeAttributes: { style: 'details.detailsStyle'}
    }
  ];

  static UNMATCHED_ADDITIONAL_COLUMNS = [
    {
      key : '0',
      size : 3,
      columns : [{
        key : '01',
        size : 9,
        label: LabelService.commonAccount,
        fieldName: {
          AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Vendor__c',
          AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Account__c',
          AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__Account__c'
        },
        editable: true,
        type: 'sobject',
        style: 'min-width:150px',
        typeAttributes: {
          fieldApiName: {
            AcctSeed__Cash_Disbursement__c : 'AcctSeed__Vendor__c',
            AcctSeed__Cash_Receipt__c : 'AcctSeed__Account__c',
            AcctSeed__Journal_Entry_Line__c : 'AcctSeed__Account__c'
          },
          required: {
            AcctSeed__Cash_Disbursement__c : true,
            AcctSeed__Cash_Receipt__c : true,
            AcctSeed__Journal_Entry_Line__c : false
          },
          recordApiName: 'proxyObj.sobjType',
          recordId: 'proxyObj.obj.Id'}
      },{
        key : '02',
        size : 9,
        label: Labels.INF_BANK_TRX_NAME,
        fieldName: 'bt.obj.Name',
        type: 'url',
        typeAttributes: {link: 'bt.recordURL'},
        cellAttributes: { alignment: 'left' }
      },{
        key : '03',
        size : 9,
        label: LabelService.commonAccountingPeriod,
        type: 'lookupPreview',
        typeAttributes: {fieldApiName: 'Name', innerRecordApiName: 'AcctSeed__Accounting_Period__c', recordId: 'accountingPeriodId'}
      },{
          key : '04',
          size : 9,
          label: LabelService.commonDescription,
          fieldName: 'proxyObj.obj.AcctSeed__Description__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {
            required: false,
            fieldApiName: 'AcctSeed__Description__c',
            recordApiName: 'proxyObj.sobjType',
            recordId: 'proxyObj.obj.Id'}
        },{
          key : '05',
          size : 9,
          label: 'Source Record Type',
          fieldName: 'selectedType',
          style: 'width: 70px',
          editable: true,
          type: 'picklist',
          typeAttributes: {options: 'availableTypes'}
        }]
    },{
      key : '1',
      size : 3,
      columns : [
        {
          key : '11',
          size : 9,
          fieldName: {
            AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Debit_GL_Account__c',
            AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Credit_GL_Account__c',
            AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__GL_Account__c'
          },
          editable: true,
          type: 'sobject',
          typeAttributes: {
            fieldApiName: {
              AcctSeed__Cash_Disbursement__c : 'AcctSeed__Debit_GL_Account__c',
              AcctSeed__Cash_Receipt__c : 'AcctSeed__Credit_GL_Account__c',
              AcctSeed__Journal_Entry_Line__c : 'AcctSeed__GL_Account__c'
            },
            required: true,
            recordApiName: 'proxyObj.sobjType',
            recordId: 'proxyObj.obj.Id'}
        },{
          key : '12',
          size : 9,
          fieldName: 'proxyObj.obj.AcctSeed__GL_Account_Variable_1__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {fieldApiName: 'AcctSeed__GL_Account_Variable_1__c', recordApiName: 'proxyObj.sobjType', recordId: 'proxyObj.obj.Id'}
      },
        {
          key : '13',
          size : 9,
          fieldName: 'proxyObj.obj.AcctSeed__GL_Account_Variable_2__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {fieldApiName: 'AcctSeed__GL_Account_Variable_2__c', recordApiName: 'proxyObj.sobjType', recordId: 'proxyObj.obj.Id'}
        },
        {
          key : '14',
          size : 9,
          fieldName: 'proxyObj.obj.AcctSeed__GL_Account_Variable_3__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {fieldApiName: 'AcctSeed__GL_Account_Variable_3__c', recordApiName: 'proxyObj.sobjType', recordId: 'proxyObj.obj.Id'}
        },
        {
          key : '15',
          size : 9,
          fieldName: 'proxyObj.obj.AcctSeed__GL_Account_Variable_4__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {fieldApiName: 'AcctSeed__GL_Account_Variable_4__c', recordApiName: 'proxyObj.sobjType', recordId: 'proxyObj.obj.Id'}
        }]
    },{
      key : '2',
      size : 3,
      columns : [{
        key : '21',
        size : 9,
        fieldName: 'proxyObj.obj.AcctSeed__Project__c',
        editable: true,
        type: 'sobject',
        typeAttributes: {fieldApiName: 'AcctSeed__Project__c', recordApiName: 'proxyObj.sobjType', recordId: 'proxyObj.obj.Id'}
      },
        {
          key : '22',
          size : 9,
          label: LabelService.commonProjectTask,
          fieldName: 'proxyObj.obj.AcctSeed__Project_Task__c',
          editable: true,
          type: 'customLookup',
          typeAttributes: {
            fieldApiName: 'AcctSeed__Project_Task__c',
            recordApiName: 'proxyObj.sobjType',
            recordId: 'proxyObj.obj.Id',
            searchFilter: {
              type: keywords.type.ID,
              field: 'AcctSeed__Project__c',
              op: keywords.op.EQUAL,
              val: ''
            }
          }
        },
        {
          key : '23',
          size : 9,
          fieldName: 'proxyObj.obj.AcctSeed__Product__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {fieldApiName: 'AcctSeed__Product__c', recordApiName: 'proxyObj.sobjType', recordId: 'proxyObj.obj.Id'}
        },{
          key : '24',
          size : 9,
          label: LabelService.commonCashFlowCategory,
          fieldName: 'proxyObj.obj.AcctSeed__Cash_Flow_Category__c',
          editable: true,
          type: 'sobject',
          typeAttributes: {
            required: true,
            fieldApiName: 'AcctSeed__Cash_Flow_Category__c',
            recordApiName: 'proxyObj.sobjType',
            recordId: 'proxyObj.obj.Id'}
        }]
    },{
      key : '3',
      size : 3,
      columns : [{
        key : '31',
        size : 9,
        label: Labels.INF_HIGH_LEVEL_CATEGORY,
        fieldName: 'bt.obj.AcctSeed__High_Level_Category__c',
        type: 'text'
      },
        {
          key : '32',
          size : 9,
          label: Labels.INF_MASTER_CATEGORY,
          fieldName: 'bt.obj.AcctSeed__Category__c',
          type: 'text'
        },
        {
          key : '33',
          size : 9,
          label: Labels.INF_DETAIL_CATEGORY,
          fieldName: 'bt.obj.AcctSeed__Detail_Category__c',
          type: 'text'
        },
        {
          key : '34',
          size : 9,
          label: 'Transaction Type',
          fieldName: 'bt.obj.AcctSeed__Type__c',
          type: 'text'
        },
        {
          key : '35',
          size : 9,
          label: 'Debit/Credit',
          fieldName: 'bt.obj.AcctSeed__Base_Type__c',
          type: 'text'
        }
        ]
    }
  ];

  static TRANSACTION_MAIN_COLUMNS = [
    {
      label: LabelService.commonActions,
      fieldName: 'actionName',
      variant: 'label-hidden',
      type: 'button'
    },{
      label: LabelService.commonDate,
      fieldName: 'bt.obj.AcctSeed__Date__c',
      type: 'date',
      sortable: true
    },{
      label: LabelService.commonAccount,
      fieldName: {
        AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Vendor__c',
        AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Account__c',
        AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__Account__c',
        AcctSeed__Bank_Deposit__c : 'proxyObj.obj.AcctSeed__Account__c'
      },
      variant: 'label-hidden',
      type: 'sobject',
      style: 'min-width:150px',
      typeAttributes: {
        fieldApiName: {
          AcctSeed__Cash_Disbursement__c : 'AcctSeed__Vendor__c',
          AcctSeed__Cash_Receipt__c : 'AcctSeed__Account__c',
          AcctSeed__Journal_Entry_Line__c : 'AcctSeed__Account__c',
          AcctSeed__Bank_Deposit__c : 'AcctSeed__Account__c'
        },
        recordApiName: 'proxyObj.sobjType',
        recordId: 'proxyObj.obj.Id'}
    },{
      label: LabelService.commonDescription,
      fieldName: 'bt.obj.AcctSeed__Description__c',
      variant: 'label-hidden',
      type: 'sobject',
      typeAttributes: {fieldApiName: 'AcctSeed__Description__c', recordApiName: 'bt.sobjType', recordId: 'bt.obj.Id'}
    },{
      label: LabelService.commonGLAccount,
      fieldName: {
        AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Debit_GL_Account__c',
        AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Credit_GL_Account__c',
        AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__GL_Account__c',
        AcctSeed__Bank_Deposit__c : 'proxyObj.obj.AcctSeed__Bank_Account__c'
      },
      variant: 'label-hidden',
      type: 'sobject',
      typeAttributes: {
        fieldApiName: {
          AcctSeed__Cash_Disbursement__c : 'AcctSeed__Debit_GL_Account__c',
          AcctSeed__Cash_Receipt__c : 'AcctSeed__Credit_GL_Account__c',
          AcctSeed__Journal_Entry_Line__c : 'AcctSeed__GL_Account__c',
          AcctSeed__Bank_Deposit__c : 'AcctSeed__Bank_Account__c'
        },
        recordApiName: 'proxyObj.sobjType',
        recordId: 'proxyObj.obj.Id'}
    },{
      label: LabelService.commonAmount,
      fieldName: 'bt.obj.AcctSeed__Amount__c',
      type: 'currency',
      sortable: true,
      typeAttributes: {
        isMultiCurrencyEnabled: 'bt.isMultiCurrencyEnabled',
        currencyCode: 'bt.currencyIsoCode',
        style: 'amountStyle.valueStyle',
        parentheses: 'amountStyle.valueParentheses'}
    },{
      label: LabelService.commonStatus,
      fieldName: 'bt.obj.AcctSeed__Status__c',
      variant: 'label-hidden',
      sortable: true,
      type: 'text'
    },{
      label: Labels.INF_SOURCE_LINK,
      fieldName: 'proxyObj.obj.Name',
      sortable: true,
      variant: 'label-hidden',
      type: 'url',
      typeAttributes: {link: 'proxyObj.recordURL'}
    }
  ];

  static TRANSACTION_ADDITIONAL_COLUMNS = [
    {
      key : '0',
      size : 3,
      columns : [{
        key : '01',
        size : 9,
        fieldName: {
          AcctSeed__Cash_Disbursement__c : 'proxyObj.obj.AcctSeed__Vendor__c',
          AcctSeed__Cash_Receipt__c : 'proxyObj.obj.AcctSeed__Account__c',
          AcctSeed__Journal_Entry_Line__c : 'proxyObj.obj.AcctSeed__Account__c',
          AcctSeed__Bank_Deposit__c : 'proxyObj.obj.AcctSeed__Account__c'
        },
        type: 'sobject',
        style: 'min-width:150px',
        typeAttributes: {
          fieldApiName: {
            AcctSeed__Cash_Disbursement__c : 'AcctSeed__Vendor__c',
            AcctSeed__Cash_Receipt__c : 'AcctSeed__Account__c',
            AcctSeed__Journal_Entry_Line__c : 'AcctSeed__Account__c',
            AcctSeed__Bank_Deposit__c : 'AcctSeed__Account__c'
          },
          recordApiName: 'proxyObj.sobjType',
          recordId: 'proxyObj.obj.Id'}
      },{
        key : '02',
        size : 9,
        label: Labels.INF_BANK_TRX_NAME,
        fieldName: 'bt.obj.Name',
        type: 'url',
        typeAttributes: {link: 'bt.recordURL'},
        cellAttributes: { alignment: 'left' }
        }]
    },{
      key : '1',
      size : 3,
      columns : [{
        key : '10',
        size : 9,
        label: 'Source Record Type',
        value: 'selectedType',
        fieldName: 'selectedType',
        type: 'text'
      },{
        key : '11',
        size : 9,
        label: Labels.INF_BANK_ID,
        fieldName: 'bt.obj.AcctSeed__Account_Id__c',
        type: 'text'
      }]
    },{
      key : '2',
      size : 3,
      columns : [{
        key : '20',
        size : 9,
        label: LabelService.commonSource,
        fieldName: 'bt.obj.AcctSeed__Source__c',
        type: 'text'
        }]
    },{
      key : '3',
      size : 3,
      columns : [{
        key : '30',
        size : 9,
        label: Labels.INF_HIGH_LEVEL_CATEGORY,
        fieldName: 'bt.obj.AcctSeed__High_Level_Category__c',
        type: 'text'
      },{
        key : '31',
        size : 9,
        label: Labels.INF_MASTER_CATEGORY,
        fieldName: 'bt.obj.AcctSeed__Category__c',
        type: 'text'
      },{
        key : '32',
        size : 9,
        label: Labels.INF_DETAIL_CATEGORY,
        fieldName: 'bt.obj.AcctSeed__Detail_Category__c',
        type: 'text'
      },
      {
        key : '33',
        size : 9,
        label: 'Transaction Type',
        fieldName: 'bt.obj.AcctSeed__Type__c',
        type: 'text'
      },
      {
        key : '34',
        size : 9,
        label: 'Debit/Credit',
        fieldName: 'bt.obj.AcctSeed__Base_Type__c',
        type: 'text'
      }]
    }
  ];

}