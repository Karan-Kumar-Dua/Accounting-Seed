import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { ErrorUtils, LabelService } from "c/utils";
import getBankRules from '@salesforce/apex/BDCBankRulesHelper.getBankRules';
import Labels from './labels';

import NAME_FIELD from '@salesforce/schema/Bank_Rule__c.Name';
import PRIORITY_FIELD from '@salesforce/schema/Bank_Rule__c.Priority__c';
import DESCRIPTION_FIELD from '@salesforce/schema/Bank_Rule__c.Description__c';

const ROW_ACTIONS = [
    { label: LabelService.commonEdit, name: 'edit' },
    { label: LabelService.automatedJobsDelete, name: 'delete' }
]

const COLUMNS = [
    { 
        label: Labels.INF_BANK_RULE_NAME, 
        fieldName: NAME_FIELD.fieldApiName, 
        initialWidth: 350 
    }, { 
        label: Labels.INF_PRIORITY_ORDER, 
        fieldName: PRIORITY_FIELD.fieldApiName, 
        type: 'number', 
        initialWidth: 125, 
    }, { 
        label: LabelService.commonDescription,       
        fieldName: DESCRIPTION_FIELD.fieldApiName
    }, {
        type: 'action', 
        typeAttributes: { 
            rowActions: ROW_ACTIONS
        }
    }
]

export default class BdcBankRulesView extends LightningElement {
    labels = {...LabelService, ...Labels};
    @api
    get bankRuleType() { 
        return this.ruleType;
    }
    set bankRuleType(value) { 
        this.ruleType = value;
        this.loadBankRules(); 
    }
    @track rules;
    @track isSpinner = false;
    @track deleteRecordId;
    @track ruleType;
    @track editRecordId;
    @track error = { title: LabelService.commonToastErrorTitle };
    columns = COLUMNS;

    loadBankRules() {
        this.isSpinner = true;
        getBankRules({ type: this.ruleType })
            .then(result => {
                this.rules = result;
                this.isSpinner = false;
            })
            .catch(error => {
                const parsedError = ErrorUtils.processError(error);
                this.error.msg = parsedError.error;
                this.isSpinner = false;
            });
    }

    handleRowAction(event) {
        const row = event.detail.row;
        switch (event.detail.action.name) {
            case 'edit':
                this.handleEdit(row);
                break;
            case 'delete':
                this.handleDelete(row);
                break;
            default:
        }
    }

    handleCreate() {
        this.editRecordId = undefined;
        const createBankRuleModal = this.fetchCreateBankRuleModal();
        createBankRuleModal.openModal();
    }

    handleEdit(row) {
        this.editRecordId = row.Id;
        const createBankRuleModal = this.fetchCreateBankRuleModal();
        createBankRuleModal.openModal();
    }

    handleCreateSuccess() {
        this.closeModals();
        this.loadBankRules();
        this.dispatchEvent(new ShowToastEvent({
            title: LabelService.commonSuccess,
            message: Labels.INF_BANK_RULE_SUCCESSFULLY_SAVED,
            variant: 'success'
        }));
    }

    handleDelete(row) {
        this.deleteRecordId = row.Id;
        const deleteModal = this.template.querySelector(`c-modal-popup-base[data-id="deleteModal"]`);
        deleteModal.openModal();
    }

    closeModals() {
        const deleteModal = this.template.querySelector(`c-modal-popup-base[data-id="deleteModal"]`);
        deleteModal.closeModal();

        const createBankRuleModal = this.fetchCreateBankRuleModal();
        createBankRuleModal.closeModal();
    }

    fetchCreateBankRuleModal() {
        return this.template.querySelector(`c-modal-popup-base[data-id="createBankRuleModal"]`);
    }

    handleDeleteSuccess() {
        this.closeModals();
        this.loadBankRules();
        this.dispatchEvent(new ShowToastEvent({
            title: LabelService.commonSuccess,
            message: Labels.INF_RECORD_SUCCESSFULLY_DELETED,
            variant: 'success'
        }));
    }

    handleDeleteError({ detail }) {
        this.closeModals();
        this.dispatchEvent(new ShowToastEvent({
            title: LabelService.commonToastErrorTitle,
            message: detail.message,
            variant: 'error'
        }));
    }

}