import { api, track, wire } from 'lwc';
import { ErrorUtils, ModalLightningElement, LabelService } from "c/utils";
import getBankRule from '@salesforce/apex/BDCBankRulesHelper.getBankRule';
import saveBankRule from '@salesforce/apex/BDCBankRulesHelper.saveBankRule';
import getFIAs from '@salesforce/apex/BDCBankRulesHelper.getFinancialInstitutionAccountOptions';
import Labels from './labels';

import BANK_RULE_OBJECT from '@salesforce/schema/Bank_Rule__c';
import NAME_FIELD from '@salesforce/schema/Bank_Rule__c.Name';
import TYPE_FIELD from '@salesforce/schema/Bank_Rule__c.Type__c';
import SOURCE_RECORD_TYPE_FIELD from '@salesforce/schema/Bank_Rule__c.Source_Record_Type__c';
import PRIORITY_FIELD from '@salesforce/schema/Bank_Rule__c.Priority__c';
import ACTIVE_FIELD from '@salesforce/schema/Bank_Rule__c.Active__c';
import DESCRIPTION_FIELD from '@salesforce/schema/Bank_Rule__c.Description__c';
import EVALUATION_TYPE_FIELD from '@salesforce/schema/Bank_Rule__c.Evaluation_Type__c';
import APPLY_TO_ALL_FIELD from '@salesforce/schema/Bank_Rule__c.Apply_To_All_Financial_Accounts__c';

export default class BdcBankRulesCreate extends ModalLightningElement {

    labels = {...LabelService, ...Labels};
    @api
    get bankRuleType() { return undefined }
    set bankRuleType(value) {
        this.rule = {
            ...this.ruleStruct(),
            [TYPE_FIELD.fieldApiName]: value
        }
        this.resetRuleState();
    }
    @api
    get bankRuleId() { return undefined }
    set bankRuleId(value) { 
        if(value) {
            this.loadBankRule(value);
        }
    }

    @track isSpinner = false;
    @track rule = this.ruleStruct();
    @track glams = [];
    @track conditions = [];
    @track actions = [];
    @track error = {};
    @track financialInstitutionOptions = [];
    @track showSrcDocTypeChangePopup = false;
    @track renderSrcDocTypeInput = true;

    ruleState = this.ruleStateStruct();
    srcDocTypeChangeEvt;

    @wire(getFIAs, {})
    loadFIAs({ data }) {
        if (data) {
            this.financialInstitutionOptions = data;
        }
    }

    get bankRuleObjectApiName() { 
        return BANK_RULE_OBJECT.objectApiName;
    }
    get nameField() { 
        return {
            apiName: NAME_FIELD.fieldApiName,
            value: this.rule[NAME_FIELD.fieldApiName]
        }
    }
    get typeField() { 
        return {
            apiName: TYPE_FIELD.fieldApiName,
            value: this.rule[TYPE_FIELD.fieldApiName]
        }
    }
    get sourceRecordTypeField() { 
        return {
            apiName: SOURCE_RECORD_TYPE_FIELD.fieldApiName,
            value: this.rule[SOURCE_RECORD_TYPE_FIELD.fieldApiName]
        }
    }
    get priorityField() { 
        return {
            apiName: PRIORITY_FIELD.fieldApiName,
            value: this.rule[PRIORITY_FIELD.fieldApiName]
        }
    }
    get activeField() { 
        return {
            apiName: ACTIVE_FIELD.fieldApiName,
            value: this.rule[ACTIVE_FIELD.fieldApiName]
        }
    }
    get descriptionField() { 
        return {
            apiName: DESCRIPTION_FIELD.fieldApiName,
            value: this.rule[DESCRIPTION_FIELD.fieldApiName]
        }
    }
    get evaluationTypeField() { 
        return {
            apiName: EVALUATION_TYPE_FIELD.fieldApiName,
            value: this.rule[EVALUATION_TYPE_FIELD.fieldApiName]
        }
    }
    get applyToAllField() { 
        return {
            apiName: APPLY_TO_ALL_FIELD.fieldApiName,
            value: this.rule[APPLY_TO_ALL_FIELD.fieldApiName]
        }
    }

    registerFocusElement() {
        this.dispatchEvent(new CustomEvent('registerfocuselement', {
            bubbles: true,
            detail: {
                focusElement: null //focus on cross button
            }
        }));
    }

    ruleStruct() {
        return {
            [NAME_FIELD.fieldApiName]: undefined,
            [TYPE_FIELD.fieldApiName]: undefined,
            [SOURCE_RECORD_TYPE_FIELD.fieldApiName]: undefined,
            [PRIORITY_FIELD.fieldApiName]: undefined,
            [ACTIVE_FIELD.fieldApiName]: undefined,
            [DESCRIPTION_FIELD.fieldApiName]: undefined,
            [EVALUATION_TYPE_FIELD.fieldApiName]: undefined,
            [APPLY_TO_ALL_FIELD.fieldApiName]: undefined
        };
    }

    ruleStateStruct() {
        return {
            rule: this.ruleStruct(),
            glams: [],
            conditions: [],
            actions: [],
            delete: {
                conditions: [],
                actions: []
            }
        }
    }

    resetRuleState() {
        const ruleState = this.ruleStateStruct();
        ruleState.rule = this.rule;
        ruleState.glams = this.glams;
        ruleState.conditions = this.conditions;
        ruleState.actions = this.actions;
        this.ruleState = ruleState;
    }

    loadBankRule(ruleId) {
        this.isSpinner = true;
        getBankRule({ ruleId: ruleId})
            .then(result => {
                this.rule = {
                    ...this.ruleStruct(),
                    ...result.rule
                };
                this.glams = result.glams;
                this.conditions = result.conditions;
                this.actions = result.actions;
                this.resetRuleState();
                this.isSpinner = false;
            })
            .catch(error => {
                const parsedError = ErrorUtils.processError(error);
                this.error = {
                    title: LabelService.commonToastErrorTitle,
                    msg: parsedError.error,
                    fatal: true
                };
                this.isSpinner = false;
            });
    }

    save() {
        this.isSpinner = true;
        const params = { 
            rule: this.ruleState.rule,
            glams: this.ruleState.glams,
            conditions: this.ruleState.conditions,
            actions: this.ruleState.actions,
            deleteConditions: this.ruleState.delete.conditions,
            deleteActions: this.ruleState.delete.actions
        }
        saveBankRule(params)
            .then(() => {
                this.dispatchEvent(new CustomEvent('save'));
                this.isSpinner = false;
            })
            .catch(error => {
                const parsedError = ErrorUtils.processError(error);
                this.error = {
                    title: undefined,
                    msg: parsedError.error,
                    fatal: false
                };
                this.isSpinner = false;
            });
    }

    handleSelectAllFIAChange(event) {
        this.glams = [];
        this.handleFIAChange(event);
        this.handleChange(event);
    }

    handleFIAChange(event) {
        this.ruleState.glams = event.detail.value || [];
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleSave() {
        this.save();
    }

    handleSrcDocTypeChangeConfirmed() {
        this.showSrcDocTypeChangePopup = false;
        this.srcDocTypeChangeEvt.target.dataset.name = SOURCE_RECORD_TYPE_FIELD.fieldApiName;
        this.handleChange(this.srcDocTypeChangeEvt);
    }

    handleSrcDocTypeChangeCanceled() {
        this.showSrcDocTypeChangePopup = false;
        // re-render the input-filed lwc
        // can only set initial value, so must re-render to clear user selection
        this.renderSrcDocTypeInput = false;
        setTimeout(() => {this.renderSrcDocTypeInput = true}, 0);
    }

    cancelSrcDocTypeChangeClosure = () => undefined;

    handleSrcDocTypeChange(event) {
        const isChanged = event.detail.value !== this.ruleState.rule[event.target.dataset.name];
        if (this.ruleState.actions.length > 0 && isChanged) {
            this.showSrcDocTypeChangePopup = true;
            this.srcDocTypeChangeEvt = event; 
        } else {
            this.handleChange(event);
        }
    }

    handleChange(event) {
        const value = event.detail.value || event.detail.checked || null;
        this.ruleState.rule[event.target.dataset.name] = value;
        this.rule[event.target.dataset.name] = value;
    }

    handleActionChange(event) {
        this.updateStateWithEvent('actions', event);
    }

    handleConditionChange(event) {
        this.updateStateWithEvent('conditions', event);
    }

    updateStateWithEvent(prop, { detail }) {
        this.ruleState[prop] = this.cp(detail.values);
        this.ruleState.delete[prop] = this.cp(detail.deleted);
    }

    cp = arr => [...arr].map(value => ({...value}));

}