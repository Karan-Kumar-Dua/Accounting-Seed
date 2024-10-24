import { keywords } from 'c/lookupKeywords';
import { DateUtils } from "c/utils";
import LANG from '@salesforce/i18n/lang';
import { LabelService } from 'c/utils';
import Labels from './labels';

export default class Helper {
    static formatDateToUTC(dateStringToConvert) {
        const dateTimeFormat = new Intl.DateTimeFormat(LANG);
        const utcDate = DateUtils.toUTC(new Date(dateStringToConvert));
        return dateTimeFormat.format(utcDate);
    }    
    
    static getGLAMColumns() {
        return Helper.GLAM_COLUMNS;
    }

    static GLAM_COLUMNS = [
        {
            label: Labels.bdcPROVIDER,
            fieldName: 'source',
            variant: 'label-hidden',
            type: 'text'
        },
        {
            label: LabelService.commonFinancialInstitution,
            fieldName: 'financialInstitutionName',
            variant: 'label-hidden',
            type: 'text'            
        },        
        {
            label: 'Connection',
            fieldName: 'connectionName',
            variant: 'label-hidden',
            type: 'text'
        },
        {
            label: Labels.INF_ACCOUNT_NAME,
            fieldName: 'name',
            variant: 'label-hidden',
            type: 'text',
            initialWidth: 400
        },
        { 
            label: LabelService.accountingHomeLedger, 
            fieldName: 'ledgerId', 
            type: 'customLookup', 
            initialWidth: 200,
            typeAttributes: {
                searchObject: 'AcctSeed__Ledger__c',
                selectedName: { fieldName: 'ledgerName' },
                selectedIcon: 'custom:custom3',
                hideSelectionIcon: true,
                disabled: {fieldName: 'fiaStatusFailed' },
                rowId: { fieldName: 'id' },
                colId: 'ledgerId', 
                errors: { fieldName: 'errors' },
                searchFilter: {
                    [keywords.logical.AND]: [
                        {field: 'Type__c', op: keywords.op.EQUAL, val: 'Transactional', type: keywords.type.STRING},
                        {field: 'Is_Shadow__c', op: keywords.op.EQUAL, val: false, type: keywords.type.BOOLEAN},
                        {field: 'Active__c', op: keywords.op.EQUAL, val: true, type: keywords.type.BOOLEAN}
                    ]
                }
            }
        },
        { 
            label: LabelService.commonBankGLAcct, 
            fieldName: 'glAccountId', 
            type: 'customLookup', 
            initialWidth: 200,
            typeAttributes: { 
                searchObject: 'AcctSeed__GL_Account__c',
                selectedName: { fieldName: 'glAccountName' },
                selectedIcon: 'custom:custom3',
                hideSelectionIcon: true,
                disabled: {fieldName: 'fiaStatusFailed' },
                rowId: { fieldName: 'id' },
                colId: 'glAccountId', 
                errors: { fieldName: 'errors' },
                searchFilter: { 
                    field: 'Bank__c', 
                    op: keywords.op.EQUAL, 
                    val: true, 
                    type: keywords.type.BOOLEAN
                }
            }
        },
        {
            label: Labels.INF_INITIAL_START_DATE, 
            fieldName: 'initialStartDate', 
            type: 'customDate', 
            initialWidth: 150,
            typeAttributes: {
                rowId: { fieldName: 'id' },
                colId: 'initialStartDate',
                errors: { fieldName: 'errors' },
                editMode: { fieldName: 'allowEditGLAM' }
            }
        },
        {
            label: LabelService.commonLastRefreshedDate,
            fieldName: 'lastRefreshedDate',
            type: 'date',
            typeAttributes: { 
                month: '2-digit', 
                day: '2-digit', 
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        {
            label: Labels.INF_FIA_STATUS,
            fieldName: 'fiaStatus',
            variant: 'label-hidden',
            type: 'text',
            wrapText: true,
            cellAttributes: {
                class: { fieldName: 'fiaStatusClass'}
            }
        }
    ];
}