import { LightningElement, api} from "lwc";
import { CommonUtils, LabelService } from "c/utils";

export default class CustomLookupPreview extends LightningElement {
  @api recordApiName;
  @api fieldApiName;
  @api fieldPath;
  @api variant = 'label-inline';
  showForm = false;
  labels = LabelService;

  @api
  set recordId(val) {
    if (val) {
      this._recordId = val;
      this.showForm = true;
    }
  }
  get recordId() {
    return this._recordId;
  }

  handleOnLoad() {
    this.setSpinner(false);
  }

  @api
  getValue() {
    const inputField = this.template.querySelector('lightning-input-field');
    return {
      field : this.fieldPath,
      value : CommonUtils.isValue(inputField) && CommonUtils.isValue(inputField.value) ? inputField.value : null
    }
  }

  @api
  setValue(value) {
    this.showForm = false;
    this.recordId = value;
  }

  setSpinner(value) {
    const spinners = this.template.querySelectorAll('lightning-spinner');
    spinners.forEach(val => {
      val.classList.add(value ? "slds-show" : "slds-hide")
    })
  }

}