import {api, LightningElement } from "lwc";
import {CommonUtils} from 'c/utils';

const ROUND_T = 'Round to 1000s';
const ROUND_A = 'Whole Amounts';

export default class FinReporterViewDataCell extends LightningElement {
  @api value;

  get itemValue() {
    let resultValue;
    if (this.value.hasOwnProperty('decimalValue')) {
      let fraction = this.fraction(this.value.rounding);
      resultValue = this.isNegative(this.value) ?
        `(${CommonUtils.getFormattedNumber(this.value.decimalValue * -1, fraction)})`
        : CommonUtils.getFormattedNumber(this.value.decimalValue, fraction);
    }
    else {
      resultValue = this.isNegative(this.value) ? this.getNegativeTextValue() : this.value.value;
    }
    return resultValue;
  }

  get itemLink() {
    return this.value.drill ? this.value.link : '';
  }

  get showLink() {
    return this.value.drill && this.value.link;
  }

  get urlClass() {
    return this.isNegative(this.value) ? ' negative-link' : '';
  }

  get textClass() {
    return this.isNegative(this.value) ? ' negative' : '';
  }

  getNegativeTextValue() {
    return this.value.value.slice(-1) === '%'
      ? `(${this.value.value.substring(1, this.value.value.length - 1)})%`
      : `(${this.value.value.substring(1)})`;
  }

  isNegative = val => val.hasOwnProperty('decimalValue') ? val.decimalValue < 0 : val.value.startsWith('-');
  fraction = val => val === ROUND_T || val === ROUND_A ? 0 : 2;
}