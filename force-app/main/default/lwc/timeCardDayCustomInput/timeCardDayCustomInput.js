import {LightningElement, api} from 'lwc';
import Labels from './labels';

export default class TimeCardDayCustomInput extends LightningElement {
    @api rowId;
    @api columnId;
    @api cellContent;
    @api editMode = false;
    labels = Labels;

    get hasComments() {
        return this.cellContent && this.isNonEmptyComments(this.cellContent.internalComment, this.cellContent.invoiceComment);
    }

    handleValueChange(event) {
        this.cellContent = {
            value: this.isNonEmptyComments(this.cellContent.internalComment, this.cellContent.invoiceComment) && this.isEmptyValue(event.target.value) ? 0 : event.target.value,
            internalComment: this.cellContent.internalComment,
            invoiceComment: this.cellContent.invoiceComment,
            internalCommentAccessible: this.cellContent.internalCommentAccessible,
            internalCommentUpdateable: this.cellContent.internalCommentUpdateable,
            invoiceCommentAccessible: this.cellContent.invoiceCommentAccessible,
            invoiceCommentUpdateable: this.cellContent.invoiceCommentUpdateable

        };
        this.fireCellChangeEvent();
    }

    isEmptyValue = (value) => value !== undefined && (value == null || value === '');

    handleCommentsChange(event) {
        this.cellContent = {
            value: !this.isNonEmptyValue() && this.isNonEmptyComments(event.detail.internalComment, event.detail.invoiceComment) ? 0 : this.cellContent.value,
            internalComment: event.detail.internalComment,
            invoiceComment: event.detail.invoiceComment,
            internalCommentAccessible: this.cellContent.internalCommentAccessible,
            internalCommentUpdateable: this.cellContent.internalCommentUpdateable,
            invoiceCommentAccessible: this.cellContent.invoiceCommentAccessible,
            invoiceCommentUpdateable: this.cellContent.invoiceCommentUpdateable
        };
        this.fireCellChangeEvent();
    }

    isNonEmptyValue = () => this.cellContent.value !== undefined && this.cellContent.value !== null;
    isNonEmptyComments = (internalComment, invoiceComment) => {
        return (internalComment !== undefined && internalComment !== null) || (invoiceComment !== undefined && invoiceComment !== null);
    }

    fireCellChangeEvent() {
        let changedCellContent = {};
        changedCellContent.id = this.rowId;
        changedCellContent[this.columnId] = this.cellContent;
        const event = new CustomEvent('customcellchange', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                changedCellContent: changedCellContent,
                columnId: this.columnId
            }
        });
        this.dispatchEvent(event);
    }

}