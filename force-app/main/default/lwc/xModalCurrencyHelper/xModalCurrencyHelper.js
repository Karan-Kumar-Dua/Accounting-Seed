import { LightningElement,api } from 'lwc';
import { LabelService } from 'c/utils';

export default class XModalCurrencyHelper extends LightningElement {
    labels = LabelService;
    @api column;
    @api row;

    get fieldValue(){
        return this.row[this.column.apiName];
    }
    get isReadOnly(){
        return !this.column.updateable;
    }
    get currencyCode(){
        return this.column.currencyCode ? this.column.currencyCode : this.row['CurrencyIsoCode'];
    }
    handleInputFocusout(evt){
        this.dispatchEvent(new CustomEvent('currencychange', {detail: {
            colId: evt.detail.colId,
            rowId: evt.detail.rowId,
            value: evt.detail.value
        }}));
    }
    get step(){
        let decimals = (this.column.typeAttributes && this.column.typeAttributes.minimumFractionDigits) ? this.column.typeAttributes.minimumFractionDigits : '1';
        return "0."+ "0".repeat(decimals-1)+"1";
    }
    get isCurrency(){
        return this.column.type === 'currency';
    }
    handleChange(evt){
        if(this.column.type === 'number' && !(evt.target.value).endsWith('.')){
            let input = this.template.querySelector('lightning-input[data-id="cell-input"]');
            let values = (evt.target.value).split('.');
            if(values.length > 1){
                values[1] = values[1].substring(0,this.column.typeAttributes.minimumFractionDigits);
            }
            input.value = values.join('.');
        }
    }
    handleBlur(evt){
        this.handleInputFocusout({detail : {
            colId : this.column.apiName,
            rowId : this.row.rowKey,
            value : evt.target.value
        }})
    }
}