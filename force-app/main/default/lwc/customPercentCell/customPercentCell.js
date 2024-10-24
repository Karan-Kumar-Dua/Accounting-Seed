import { LightningElement, api, track } from 'lwc';

export default class CustomPercentCell extends LightningElement {

    @api maximumFractionDigits;
    @api minimumFractionDigits;

    @api
    get value() {
        return isNaN(this._value) ? undefined : this._value * 100;
    }
    set value(val) {
        this._value = isNaN(val) ? undefined : val / 100;
    }

    @track _value;

}