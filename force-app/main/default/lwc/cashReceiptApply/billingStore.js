import { AbstractItemsStore, CommonUtils } from "c/utils";

export default class BillingStore extends AbstractItemsStore {
    idKey = 'billingId';
    
    getItems() {
        this.values = this.values.map(item => this.flattenObject(item));
        return this.values;
    }

    setItems(items) {
        this.values = items.map(item => this.addDerivedFields(item));
        this.changes = [];
        this.values = this.values.map(value => { 
            if (value.isDirty === true && !this.changes.includes(value.billingId)) {
                this.changes.push(value.billingId);                
            }
            return value;
        });
    }

    updateItem(item) {
        item = this.updateApplyIcon(item);
        super.updateItem(item);
    }

    zeroOut(itemId) {
        let item = this.getItem(itemId);

        item.balance = CommonUtils.round(item.balance + item.appliedAmount + item.adjustmentAmount);
        item.applied = CommonUtils.round(item.total - item.balance);
        item.appliedAmount = 0;
        item.adjustmentAmount = 0;

        this.updateItem(item);
    }

    applyCredit(amount, itemId) {
        let item = this.getItem(itemId);

        item.appliedAmount = CommonUtils.round(item.appliedAmount + amount);
        item.applied = CommonUtils.round(item.applied + amount);
        item.balance = CommonUtils.round(item.balance - amount);

        this.updateItem(item);
    }

    applyAdjustment(amount, itemId) {
        let item = this.getItem(itemId);

        item.adjustmentAmount = CommonUtils.round(item.adjustmentAmount + amount);
        item.applied = CommonUtils.round(item.applied + amount);
        item.balance = CommonUtils.round(item.balance - amount);

        this.updateItem(item);
    }

    addError(itemId, fieldname, msg) {
        super.addError(itemId, fieldname, msg);
        this.updateItem(super.getItem(itemId));
    }

    addDerivedFields = item => {
        let update = {...item};
        update = this.addCurrency(update);
        update = this.addErrors(update);
        update = this.addName(update);
        update = this.addApplyIcon(update);
        return update;
    }

    addErrors = item => {
        item.errors = [];
        return item;
    };

    addName = item => {
        item.derivedName = item.proprietaryName ? item.proprietaryName : item.name;
        return item;
    };

    addApplyIcon = item => { 
        item.applyIcon = this.getApplyIcon(item);
        return item;
    };

    updateApplyIcon = item => { 
        item.applyIcon = this.getApplyIcon(item);
        return item;
    };

    getApplyIcon = item => {
        return item.appliedAmount > 0 ? 'utility:back' : 'utility:forward';
    };

}