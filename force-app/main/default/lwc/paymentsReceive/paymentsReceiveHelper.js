import { LabelService } from "c/utils";
import Labels from "./labels";
import {keywords} from "c/lookupKeywords";

export default class Helper {

    static getMainColumns() {
        return Helper.MAIN_COLUMNS;
    }

    static getAdditionalColumns() {
        return Helper.ADDITIONAL_COLUMNS;
    }

    static MAIN_COLUMNS = [
        {
            label: LabelService.commonStatus,
            fieldName: 'statusDetails',
            variant: 'label-hidden',
            isShowRowSpinner: 'isShowStatusSpinner',
            type: 'combined'
        },
        {
            label: LabelService.customer,
            fieldName: 'customerName',
            type: 'url',
            variant: 'label-hidden',
            typeAttributes: {link: 'customerUrl'},
            cellAttributes: { alignment: 'left' }
        },
        {
            label: LabelService.bankAccount,
            editable: true,
            fieldName: 'cashReceipt.obj.AcctSeed__Bank_Account__c',
            dynamicFieldName: 'bankAccountFieldName',
            type: 'dynamic',
            dynamicType: 'bankAccountType',
            style: 'min-width:150px',
            variant: 'label-hidden',
            typeAttributes: {
                required: true,
                fieldApiName: 'AcctSeed__GL_Account__c',
                searchFilter: { 
                    type: keywords.type.BOOLEAN,
                    field: 'AcctSeed__Bank__c',
                    op: keywords.op.EQUAL,
                    val: true
                },
                recordApiName: 'cashReceipt.sobjType',
                recordId: 'cashReceipt.obj.Id',
                link: 'bankAccountUrl'
            }
        },{
            label: LabelService.paymentProcessor,
            fieldName: 'selectedPP',
            style: 'min-width: 90px',
            editable: true,
            variant: 'label-hidden',
            type: 'picklist',
            isShowRowSpinner: 'isShowProcessorSpinner',
            typeAttributes: {options: 'availablePP'}
        },{
            label: LabelService.paymentMethod,
            fieldName: 'selectedPM',
            style: 'min-width: 90px;max-width: 500px',
            editable: true,
            variant: 'label-hidden',
            type: 'picklist',
            isShowRowSpinner: 'isShowProcessorSpinner',
            typeAttributes: {options: 'availablePM'}

        },{
            label: LabelService.billingTotal,
            fieldName: 'billingsTotal',
            type: 'currency',
            typeAttributes: {
                isMultiCurrencyEnabled: 'isMultiCurrencyEnabled',
                currencyCode: 'currencyIsoCode'}
        },{
            label: Labels.colPriorReceivedAmount,
            fieldName: 'priorAmount',
            type: 'currency',
            typeAttributes: {
                isMultiCurrencyEnabled: 'isMultiCurrencyEnabled',
                currencyCode: 'currencyIsoCode'}
        },{
            label: Labels.confee,
            fieldName: 'convenienceFee',
            type: 'currency',
            typeAttributes: {
                isMultiCurrencyEnabled: 'isMultiCurrencyEnabled',
                currencyCode: 'currencyIsoCode'}
        },{
            label: Labels.commonPaymentAmt,
            fieldName: 'paymentAmount',
            type: 'currency',
            typeAttributes: {
                isMultiCurrencyEnabled: 'isMultiCurrencyEnabled',
                currencyCode: 'currencyIsoCode'}
        }
    ];

    static ADDITIONAL_COLUMNS = [
        {
            key : '0',
            size : 2,
            columns : [{
                key : '01',
                size : 11,
                label: LabelService.ledger,
                fieldName: 'ledgerName',
                type: 'url',
                typeAttributes: {link: 'ledgerUrl'},
                cellAttributes: { alignment: 'left' }


            },
            {
                key : '02',
                size : 12,
                label: Labels.includeConvenienceFees,
                helptext: Labels.includeConvenienceFeesHelp,
                fieldName: 'includeConFee', 
                type: 'checkbox',
                typeAttributes: {fieldLevelHelp:Labels.includeConvenienceFeesHelp, 
                                state : 'disableIncludeFee',
                                link: 'ledgerUrl'},
                cellAttributes: { alignment: 'left' }
            }]
        },
        {
            key : '1',
            size : 2,
            columns : [{
                key : '11',
                size : 11,

                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__GL_Account_Variable_1__c',
                type: 'sobject',
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__GL_Account_Variable_1__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id'}

            }]
        },
        {
            key : '2',
            size : 2,
            columns : [{
                key : '21',
                size : 11,

                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__GL_Account_Variable_2__c',
                type: 'sobject',
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__GL_Account_Variable_2__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id'}
            },{
                key : '22',
                size : 11,

                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__Project__c',
                type: 'sobject',
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__Project__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id'}
            }]
        },
        {
            key : '3',
            size : 2,
            columns : [{
                key : '31',
                size : 11,

                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__GL_Account_Variable_3__c',
                type: 'sobject',
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__GL_Account_Variable_3__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id'}

            },{
                key : '32',
                size : 11,
                label: LabelService.commonProjectTask,
                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__Project_Task__c',
                type: 'customLookup',
                hideBumper: true,
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__Project_Task__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id',
                    searchFilter: {
                        type: keywords.type.ID,
                        field: 'AcctSeed__Project__c',
                        op: keywords.op.EQUAL,
                        val: {
                            fieldApiName: 'cashReceipt.obj.AcctSeed__Project__c'
                        }
                    }
                }
            }]
        },
        {
            key : '4',
            size : 2,
            columns : [{
                key : '41',
                size : 11,

                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__GL_Account_Variable_4__c',
                type: 'sobject',
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__GL_Account_Variable_4__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id'}
            },{
                key : '42',
                size : 11,

                editable: true,
                fieldName: 'cashReceipt.obj.AcctSeed__Product__c',
                type: 'sobject',
                style: 'min-width:150px',
                typeAttributes: {
                    required: false,
                    fieldApiName: 'AcctSeed__Product__c',
                    recordApiName: 'cashReceipt.sobjType',
                    recordId: 'cashReceipt.obj.Id'}
            }]
        }
    ];

}