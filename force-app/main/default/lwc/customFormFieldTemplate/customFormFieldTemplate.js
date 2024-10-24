import { LightningElement, api } from "lwc";
import { CommonUtils, LabelService } from "c/utils";
import Labels from './labels';

export default class CustomFormFieldTemplate extends LightningElement {

  labels = {...LabelService, ...Labels};
  @api editMode = false;
  @api recordId;
  @api recordApiName;
  @api fieldApiName;
  @api customValue;
  @api fieldPath;
  @api standardSubmit = false;
  @api variant = 'label-inline';
  @api isEditable = false;
  @api required = false;
  showError = false;

  handleEdit() {
    if (this.isEditable) {
      this.editMode = true;
      this.dispatchEvent(new CustomEvent('editaction', { bubbles: true, composed: true }));
    }
  }

  handleOnLoad() {
    this.showError = this.recordApiName && this.recordId;
    this.setSpinner(false);
    const inputField = this.template.querySelector('lightning-input-field');
    this.dispatchEvent(new CustomEvent('loadcell', {
      detail: {
        fieldApiName: this.fieldPath,
        value: CommonUtils.isValue(inputField) && CommonUtils.isValue(inputField.value) ? inputField.value : ''
      }
    }));
  }

  @api
  setEdit(value) {
    if (this.isEditable) {
      this.editMode = value;
    }
  }

  @api
  setRequired(value) {
    this.required = value;
  }

  @api
  getRequired() {
    return this.required;
  }

  @api
  isValueChanged() {
    const inputField = this.template.querySelector('lightning-input-field');
    return CommonUtils.isValue(inputField) && CommonUtils.isValue(inputField.value) ? inputField.value !== this.customValue : false
  }

  @api
  getValue() {
    const inputField = this.template.querySelector('lightning-input-field');
    return {
      field : this.fieldPath,
      value : CommonUtils.isValue(inputField) && CommonUtils.isValue(inputField.value) ? inputField.value : ''
    }
  }

  @api
  submitData(){
    if (this.editMode !== false && this.standardSubmit === true) {
      this.template.querySelector('lightning-record-edit-form').submit();
    }
  }

  @api
  isValidField() {
    let isValid = true;
    if (this.required) {
      const inputField = this.template.querySelector('lightning-input-field');
      if (CommonUtils.isValue(inputField)) {
        inputField.reportValidity();
        isValid = !inputField.value ? false : true;
      }
    }
    return isValid;
  }

  setSpinner(value) {
    const spinners = this.template.querySelectorAll('lightning-spinner');
    spinners.forEach(val => {
      val.classList.add(value ? "slds-show" : "slds-hide")
    })
  }

  handleChange() {
    const inputField = this.template.querySelector('lightning-input-field');
    this.dispatchEvent(new CustomEvent('selectvalue',
      {
        bubbles: true,
        composed: true,
        detail: {
          value : CommonUtils.isValue(inputField) && CommonUtils.isValue(inputField.value) ? inputField.value : '',
          fieldApiName : this.fieldPath}})
    );
  }
}