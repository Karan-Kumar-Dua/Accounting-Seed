import { LightningElement, api, track, wire } from 'lwc';
import getActionFields from '@salesforce/apex/BDCBankRulesHelper.getActionFields';
import { LabelService } from "c/utils";
import VALUE_FIELD from '@salesforce/schema/Bank_Rule_Action__c.Value__c';

export default class BdcBankRulesActionForm extends LightningElement {
    labels = LabelService;
    @api 
    get values() { return undefined }
    set values(value) {
        this.actions = this.index(value);
    }
    @api bankRuleType;
    @api bankRuleSourceDocType;
   
    @track actions = this.index();
    
    deleted = [];

    @wire(getActionFields, { ruleType: '$bankRuleType', sourceDocType: '$bankRuleSourceDocType'})
    actionFieldOpts;

    get actionFieldOptions() {
        return this.actionFieldOpts && this.actionFieldOpts.data || [];
    }

    get srcDoc() {
        return this.actions
            .filter(action => action.action[VALUE_FIELD.fieldApiName])
            .map(action => JSON.parse(action.action[VALUE_FIELD.fieldApiName]))
            .reduce((acc, action) => ({ ...acc, ...action }), {});
    }

    fillIfEmpty(xs = []) {
        return Array.isArray(xs) && xs.length === 0 ? [{}] : xs;
    }

    index(xs = []) {
        return this.fillIfEmpty(xs).map((x, index) => ({ idx: Date.now() + index, action: x }));
    }

    removeIndex(xs = []) {
        return xs.map(x => x.action);
    }

    handleAddAction() {
        this.actions.push({ idx: Date.now(), action: {} });
    }

    handleChange({ detail }) {
        this.actions = this.actions.map(action => {
            if(action.idx === detail.index) {
                action.action = detail.values;
            } 
            return action;
        });
        this.dispatchChange();
    }

    handleDelete({ detail }) {
        const deletedAction = this.actions.find(action => action.idx === detail.index);
        if(deletedAction.action.Id) {
            this.deleted.push(deletedAction.action);
        }
        this.actions = this.actions.filter(action => action.idx !== detail.index);
        this.dispatchChange();
        if (this.actions.length < 1) {
            this.actions = this.index();
        }
    }

    dispatchChange() {
        this.dispatchEvent(new CustomEvent('change', { detail: { 
            values: this.removeIndex(this.actions).filter(action => JSON.stringify(action) !== '{}'),
            deleted: this.deleted
        }}));
    }

}