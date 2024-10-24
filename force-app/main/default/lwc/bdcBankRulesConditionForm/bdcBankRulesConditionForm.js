import { LightningElement, api, track } from 'lwc';
import { LabelService } from "c/utils";

export default class BdcBankRulesConditionForm extends LightningElement {
    labels = LabelService;
    @api 
    get values() { return undefined }
    set values(value) {
        this.conditions = this.index(value);
    }

    @track conditions = this.index();
    deleted = [];

    fillIfEmpty(xs = []) {
        return xs.hasOwnProperty('length') && xs.length === 0 ? [{}] : xs;
    }

    index(xs = []) {
        return this.fillIfEmpty(xs).map((x, index) => ({ idx: index, condition: x }));
    }

    removeIndex(xs = []) {
        return xs.map(x => x.condition);
    }

    handleAddCondition() {
        this.conditions.push({ idx: this.conditions.length.toString(), condition: {} });
    }

    handleChange({ detail }) {
        this.conditions = this.conditions.map(condition => {
            if(condition.idx === detail.index) {
                condition.condition = detail.values;
            } 
            return condition;
        });
        this.dispatchChange();
    }

    handleDelete({ detail }) {
        const deletedCondition = this.conditions.find(condition => condition.idx === detail.index);
        if(deletedCondition.condition.Id) {
            this.deleted.push(deletedCondition.condition);
        }
        this.conditions = this.conditions.filter(condition => condition.idx !== detail.index);
        this.dispatchChange();
    }

    dispatchChange() {
        this.dispatchEvent(new CustomEvent('change', { detail: { 
            values: this.removeIndex(this.conditions),
            deleted: this.deleted
        }}));
    }

}