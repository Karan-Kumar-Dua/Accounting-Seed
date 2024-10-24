import { LightningElement, api, track} from 'lwc';
import { LabelService } from "c/utils";
import Labels from './labels';
export default class AppliedAmountCalculator extends LightningElement {
    labels = {...LabelService,...Labels};
    @api currencyCode = 'USD';
    @api isMultiCurrencyEnabled = false;
    @track _total = 0;
    @track _applied = 0;
    @track _convenienceFee = 0;
    hasConvenienceFee = false;

    @api
    set total(val) {
        this._total = this.numberOrZero(val);
    }
    get total() {
        return this._total;
    }

    @api
    set convenienceFee(val) {
        this.hasConvenienceFee = true;
        this._convenienceFee = this.numberOrZero(val);
    }
    get convenienceFee() {
        return this._convenienceFee;
    }
    @api
    set applied(val) {
        this._applied = this.numberOrZero(val);
    }
    get applied() {
        return this._applied;
    }

    get balance() {
        let balance = (parseFloat(this._total).toFixed(5) - parseFloat(this._applied).toFixed(5) - parseFloat(this._convenienceFee).toFixed(5)).toFixed(5);
        const zero = parseFloat(0).toFixed(5);
        return Math.abs(parseFloat(balance)).toFixed(5) === zero ? zero : balance; // to avoid -0 when using toFixed. example: (-0.0000000000001).toFixed(5) => -0.00000
    }

    get balanceStyle() {
        return this.balance < 0 ? 'slds-text-heading_small slds-text-color_error' : 'slds-text-heading_small';
    }

    numberOrZero = val => { return ( isNaN(val) ? 0 : val ) || 0; };

}