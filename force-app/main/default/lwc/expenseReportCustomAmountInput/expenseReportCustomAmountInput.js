import {LightningElement, api} from 'lwc';

export default class ExpenseReportCustomAmountInput extends LightningElement {

    @api amount;
    @api isMultiCurrencyEnabled;
    @api currency;
    @api internalComment;
    @api invoiceComment;
    @api editMode = false;
    @api isMileage = false;
    @api rowId;
    @api colId;

    get hasComments() {
        return ((this.internalComment.stringValue !== undefined && this.internalComment.stringValue !== null)
            || (this.invoiceComment.stringValue !== undefined && this.invoiceComment.stringValue !== null));
    }

    get viewMode() {
        return !(this.editMode && !this.isMileage);
    }

    handleValueChange(event) {
        this.fireCellChangeEvent({
            amount: event.target.value,
            internalComment: this.internalComment,
            invoiceComment: this.invoiceComment
        });
    }

    handleCommentsChange(event) {
        this.fireCellChangeEvent({
            amount: this.amount,
            internalComment: {stringValue: event.detail.internalComment},
            invoiceComment: {stringValue: event.detail.invoiceComment},
            isMileage: this.isMileage,
            isMultiCurrencyEnabled: this.isMultiCurrencyEnabled,
            currency: this.currency
        });
    }

    fireCellChangeEvent(cellContent) {
        const event = new CustomEvent('customcellchange', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                rowId: this.rowId,
                colId: this.colId,
                value: cellContent
            }
        });
        this.dispatchEvent(event);
    }

}