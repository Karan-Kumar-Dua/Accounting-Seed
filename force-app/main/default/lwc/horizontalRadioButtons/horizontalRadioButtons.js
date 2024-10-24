import { LightningElement, api } from "lwc";

export default class HorizontalRadioButtons extends LightningElement {
  @api defaultValue;
  @api options;
  @api groupId = 'radiogroup';

  // handle the selected value
  handleSelected(event) {
    this.selectedValue = event.target.value;
    this.dispatchEvent(new CustomEvent('selectvalue', { detail: { value : this.selectedValue}}));
  }
}