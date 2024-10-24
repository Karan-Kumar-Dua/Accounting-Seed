import { LightningElement, api,wire } from 'lwc';
import { LabelService } from "c/utils";
import { getObjectInfo,getPicklistValues } from 'lightning/uiObjectInfoApi'
import BANK_RULE_CONDITION_OBJECT from '@salesforce/schema/Bank_Rule_Condition__c';
import TARGET_FIELD from '@salesforce/schema/Bank_Rule_Condition__c.Target_Field__c';
import OPERATOR_FIELD from '@salesforce/schema/Bank_Rule_Condition__c.Operator__c';
import BASE_TYPE_FIELD from '@salesforce/schema/Bank_Rule_Condition__c.Base_Type__c';
import BANK_RULE_OBJECT from '@salesforce/schema/Bank_Rule_Condition__c';

export default class BdcBankRulesConditionFormItem extends LightningElement {
    
    labels = LabelService;
    @api index;
    @api 
    get values() { return undefined }
    set values(value = {}) {
        this.condition = {
            ...this.conditionStruct(),
            ...value
        };
    }
    @wire(getObjectInfo, { objectApiName: BANK_RULE_OBJECT})
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName : BASE_TYPE_FIELD })
    baseTypePicklistField;

    get options() {
        let types = [];
        if (this.baseTypePicklistField && this.baseTypePicklistField.data) {
            types = [...types, ...this.baseTypePicklistField.data.values];
        }
        return types;
    }
    condition = this.conditionStruct();

    get bankRuleConditionObjectApiName() { 
        return BANK_RULE_CONDITION_OBJECT.objectApiName;
    }
    get targetField() { 
        return {
            apiName: TARGET_FIELD.fieldApiName,
            value: this.condition[TARGET_FIELD.fieldApiName]
        }
    }
    get operatorField() { 
        return {
            apiName: OPERATOR_FIELD.fieldApiName,
            value: this.condition[OPERATOR_FIELD.fieldApiName]
        }
    }
    get criteriaField() { 
        return {
            apiName: this.condition[TARGET_FIELD.fieldApiName],
            value: this.condition[this.condition[TARGET_FIELD.fieldApiName]] || ''
        }
    }

    get displayCriteria() {
        return this.condition[TARGET_FIELD.fieldApiName] 
            && this.condition[OPERATOR_FIELD.fieldApiName] !== 'Is_Blank'
            && this.condition[TARGET_FIELD.fieldApiName] !== BASE_TYPE_FIELD.fieldApiName ;
    }
    get displayCreditDebitField() {
        return this.condition[TARGET_FIELD.fieldApiName]
                && this.condition[TARGET_FIELD.fieldApiName] === BASE_TYPE_FIELD.fieldApiName
                && this.condition[OPERATOR_FIELD.fieldApiName] !== 'Is_Blank'
    }

    get displayDeleteBtn() {
        return this.index !== 0;
    }

    conditionStruct() {
        return {
            [TARGET_FIELD.fieldApiName]: "",
            [OPERATOR_FIELD.fieldApiName]: ""
        };
    }

    handleChange(event) {
        event.preventDefault();
        event.stopPropagation();
        this.condition[event.target.dataset.name] = (event.detail && event.detail.value) || event.target.value;
        this.dispatchEvent(new CustomEvent('change', { detail: { 
            index: this.index, 
            values: this.condition
        }}));
    }
    handleRemove() {
        this.dispatchEvent(new CustomEvent('delete', { detail: { index: this.index }}));
    }
}