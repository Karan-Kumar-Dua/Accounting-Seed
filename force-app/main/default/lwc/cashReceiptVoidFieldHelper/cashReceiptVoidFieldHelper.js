import { LightningElement, api } from 'lwc';

export default class CashReceiptVoidFieldHelper extends LightningElement {
    @api fieldValue;
    @api fieldInfo;
    @api inEditMode=false;
    @api filter;

    handleValueChange(evt){
        this.dispatchEvent(new CustomEvent('valuechange', { detail: {
            value: (evt.detail && evt.detail.recordId) || evt?.target?.value
        }}));
    }
}