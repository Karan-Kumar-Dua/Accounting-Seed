import { LightningElement, api, track, wire } from 'lwc';
import { keywords } from 'c/lookupKeywords';
import { LabelService } from "c/utils";

import PROJECT_OBJECT from '@salesforce/schema/Project__c';
import PROJECT_TASK_OBJECT from '@salesforce/schema/Project_Task__c';

import VALUE_FIELD from '@salesforce/schema/Bank_Rule_Action__c.Value__c';
import TARGET_FIELD from '@salesforce/schema/Bank_Rule_Action__c.Target_Field__c';

export default class BdcBankRulesActionFormItem extends LightningElement {

    labels = {...LabelService};
    @api index;
    @api objectApiName;
    @api position;
    @api 
    get objectDefaults() { return undefined }
    set objectDefaults(value = {}) { 
        this.defaults = value;
        this.setFieldDefaults();
        this.setDependentLookupFields();
    } 
    @api 
    get fieldOptions() { return undefined }
    set fieldOptions(value = []) {
        if (this.fieldOpts && this.fieldOpts.length > 0) {
            this.handleRemove();
        } else {
            this.fieldOpts = value;
            this.selectField(this.action[TARGET_FIELD.fieldApiName]);
            this.setFieldDefaults();
            this.setDependentLookupFields();
            this.removeIfInvalid();
        }
    }
    @api
    get values() { return undefined }
    set values(value = {}) {
        this.action = {
            ...this.actionStruct(),
            ...value
        };
        this.action[VALUE_FIELD.fieldApiName] = this.getActionValueFromJSON();
        this.selectField(this.action[TARGET_FIELD.fieldApiName]);
        this.removeIfInvalid();
    }

    defaults = {};
    fieldOpts = [];
    action = this.actionStruct();

    get targetField() {
        return {
            apiName: TARGET_FIELD.fieldApiName,
            value: this.action[TARGET_FIELD.fieldApiName]
        }
    }
    get valueField() {
        return {
            apiName: VALUE_FIELD.fieldApiName,
            value: this.action[VALUE_FIELD.fieldApiName]
        }
    }

    get hasObjectApiName() {
        return this.objectApiName ? true : false;
    }

    get displayDeleteBtn() {
        return this.position !== 0;
    }

    actionStruct() {
        return {
            [TARGET_FIELD.fieldApiName]: undefined,
            [VALUE_FIELD.fieldApiName]: undefined 
        };
    }

    selectField(fieldName) {
        this.fieldOpts = this.fieldOpts.map(opt => {
            return {
                ...opt,
                selected: opt.value === fieldName
            };
        });
    }

    setFieldDefaults() {
        this.fieldOpts = this.fieldOpts.map(opt => {
            return {
                ...opt,
                default: this.defaults[opt.value]
            };
        });
    }

    setDependentLookupFields() {
        this.fieldOpts = this.fieldOpts.map(opt => {
            return {
                ...opt,
                isDependentLookup: opt.value === PROJECT_TASK_OBJECT.objectApiName ? true : false,
                dependentLookupFilter: {
                    type: keywords.type.ID,
                    field: PROJECT_OBJECT.objectApiName,
                    op: keywords.op.EQUAL,
                    val: this.defaults[PROJECT_OBJECT.objectApiName]
                }
            };
        });
    }

    removeIfInvalid() {
        const fieldname = this.action[TARGET_FIELD.fieldApiName];
        const valid = 
               !fieldname 
            || this.fieldOpts.length < 1 
            || this.fieldOpts.find(opt => opt.value === fieldname) 
            ? true : false;
        if (!valid) {
            this.handleRemove();
        }
    }

    handleFieldChange(event) {
        this.action = { 
            ...this.action,
            ...this.actionStruct()
        };
        this.updateActionValues(event);
        this.selectField(event.detail.value);
    }

    handleValueChange(event) {
        this.updateActionValues(event);
    }

    handleDependentLookupChange(event) {
        const detail = event.detail;
        if (detail) {
            event.detail.value = detail ? detail.recordId : undefined;
        } else {
            event = {
                ...event,
                detail: { value: [] }
            };
        }
        this.updateActionValues(event);
    }

    updateActionValues(event) {
        event.preventDefault();
        event.stopPropagation();
        const value = this.getValueFromEvent(event);
        this.action[event.target.dataset.name] = value;
        this.dispatchEvent(new CustomEvent('change', { detail: { 
            index: this.index, 
            values: { 
                ...this.action,
                [VALUE_FIELD.fieldApiName]: this.getActionValueAsJSON()
            }
        }}));
    }

    handleRemove() {
        this.dispatchEvent(new CustomEvent('delete', { detail: { index: this.index }}));
    }

    getActionValueFromJSON() {
        try {
            const json = JSON.parse(this.action[VALUE_FIELD.fieldApiName]);
            return json[this.action[TARGET_FIELD.fieldApiName]];
        } catch(_) {
            return undefined;
        }
    }

    getActionValueAsJSON() {
        try {
            let obj = {};
            const prop = this.action[TARGET_FIELD.fieldApiName];
            const value = this.action[VALUE_FIELD.fieldApiName];
            obj[prop] = value;
            return JSON.stringify(obj);
        } catch(_) {
            return undefined;
        }
    }

    takeFirst(arr) {
        if (Array.isArray(arr) && arr.length > 0) {
            return arr[0];
        } else if (Array.isArray(arr) && arr.length < 1) {
            return undefined;
        }
        return arr;
    }

    getValueFromEvent(event) {
        const detail = event.detail;
        const prop = [
            'checked',
            'recordId',
            'value'
        ].find(prop => detail.hasOwnProperty(prop));
        const value = prop ? this.takeFirst(detail[prop]) : detail;
        return value === '' ? undefined : value;
    }

}