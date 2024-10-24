import {AbstractItemsStore, CommonUtils} from 'c/utils'

export default class PayableStore extends AbstractItemsStore {
    idKey = 'payableId';

    updateItem(item) {
        item = this.updateApplyIcon(item);
        super.updateItem(item);
    }

    applyCredit(amount, itemId) {
        let item = this.getItem(itemId);

        const variableCredit = item.variableCredit ? item.variableCredit : 0,
            total = item.total ? item.total : 0,
            applied = item.applied ? item.applied : 0;

        item.variableCredit = CommonUtils.round(variableCredit + amount);
        item.applied = CommonUtils.round(applied + amount);
        item.balance = CommonUtils.round(total - applied - amount);

        this.updateItem(item);
    }

    addError(itemId, fieldname, msg) {
        let item = this.getItem(itemId);
        item.errors = [{
            column: fieldname,
            msg: msg
        }];
        this.updateItem(item);
    }

    addDerivedFields = item => {
        let update = {...item};
        update = this.addCurrency(update);
        update = this.addErrors(update);
        update = this.addName(update);
        update = this.addInvoiceUrl(update);
        update = this.addApplyIcon(update);
        update = this.addEditable(update);
        return update;
    }

    addCurrency = item => {
        item.currency = this.currencyCode;
        item.isMultiCurrencyEnabled = this.isMultiCurrencyEnabled;
        return item;
    }

    addErrors = item => {
        item.errors = [];
        return item;
    };

    addName = item => {
        item.derivedName = item.proprietaryName ? item.proprietaryName : item.name;
        return item;
    };

    addInvoiceUrl = item => {
        item.invoiceUrl = CommonUtils.getRecordViewPath(item.payableId);
        return item;
    }

    addApplyIcon = item => {
        item.applyIcon = this.getApplyIcon(item);
        return item;
    };

    updateApplyIcon = item => {
        item.applyIcon = this.getApplyIcon(item);
        return item;
    };

    getApplyIcon = item => {
        return item.variableCredit > 0 ? 'utility:back' : 'utility:forward';
    };

    flattenObject(obj) {
        const flattened = {};
        Object.keys(obj).forEach((key) => {
            if (typeof obj[key] === 'object' && obj[key] !== null && key === 'extraFields') {
                Object.assign(flattened, this.flattenObject(obj[key]));
            } else {
                flattened[key] = obj[key];
            }
        });
        return flattened;
    }
}