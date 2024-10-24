import { LightningElement, api } from "lwc";
import { CommonUtils } from "c/utils";

const DYNAMIC_COL_TYPE = 'dynamic';

export default class CustomCell extends LightningElement {
  @api column;
  @api row;
  @api editMode;

  get columnFieldName() {
    return (this.row && this.column?.dynamicFieldName && this.row[this.column.dynamicFieldName])
        || this.column?.fieldName;
  }
  get columnType() {
    return (
        this.column && this.row && this.column.type === DYNAMIC_COL_TYPE && this.column.dynamicType && this.row[this.column.dynamicType]
    ) || this.column?.type;
  }
  get currency() {
    return this.columnType === 'currency';
  }
  get sobject() {
    return this.columnType === 'sobject';
  }
  get url() {
    return this.columnType === 'url';
  }
  get date() {
    return this.columnType === 'date';
  }
  get text() {
    return this.columnType === 'text';
  }
  get picklist() {
    return this.columnType === 'picklist';
  }
  get picklistTitle() {
    return this.picklist
        && this.value?.options
        && this.value?.fieldName
        && this.value.options.find(option => option.value === this.value?.fieldName)?.label;
  }
  get lookupPreview() {
    return this.columnType === 'lookupPreview';
  }
  get button() {
    return this.columnType === 'button';
  }
  get combined() {
    return this.columnType === 'combined';
  }
  get customLookup() {
    return this.columnType === 'customLookup';
  }
  get checkbox() {
    return this.columnType === 'checkbox';
  }

  get bumperClasses() {
    return CommonUtils.computeClasses([!this.column.hideBumper && 'slds-p-around_xx-small']);
  }

  innerValueObject;
  recordApiName;

  get isSpinner() {
    return this.column.isShowRowSpinner && this.row[this.column.isShowRowSpinner];
  }

  get value() {
    this.recordApiName = this.column.typeAttributes !== undefined ? this.getRecordApiName(this.column.typeAttributes.recordApiName) : null;
    let fieldPath;
    let fieldName;
    if (typeof this.columnFieldName === 'object' && this.recordApiName != null) {
      fieldPath = this.columnFieldName !== undefined ? this.columnFieldName[this.recordApiName] : null;
      fieldName = this.columnFieldName !== undefined ? this.getDataValue(this.columnFieldName[this.recordApiName], this.row) : null;
    }
    else {
      fieldPath = this.columnFieldName !== undefined ? this.columnFieldName : null;
      fieldName = this.columnFieldName !== undefined ? this.getDataValue(this.columnFieldName, this.row) : null;
    }

    this.innerValueObject = {
      label: this.getValid(this.column.label),
      fieldName: fieldName,
      fieldPath: fieldPath,
      link: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.link) : null,
      fieldApiName: this.getFieldApiName(),
      recordApiName: this.recordApiName,
      innerRecordApiName: this.column.typeAttributes !== undefined ? this.getValid(this.column.typeAttributes.innerRecordApiName) : null,
      recordId: this.getRecordId(),
      options: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.options) : null,
      state: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.state) : null,
      isMultiCurrencyEnabled: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.isMultiCurrencyEnabled) : null,
      currencyCode: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.currencyCode) : null,
      variant: this.column.variant !== undefined ? this.column.variant : null,
      isEditable: this.column.editable !== undefined ? this.column.editable : null,
      style: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.style) : null,
      parentheses: this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.parentheses) : null,
      searchFilter: this.column.typeAttributes !== undefined
          ? (
              this.column.typeAttributes.searchFilter?.val?.fieldApiName
                  ? {...this.column.typeAttributes.searchFilter, val: this.getDataValue(this.column.typeAttributes.searchFilter?.val?.fieldApiName, this.row)}
                  : this.getValid(this.column.typeAttributes.searchFilter)
          )
          : null,
      required: this.getRequired(),
      fieldLevelHelp: this.column.typeAttributes !== undefined && this.column.typeAttributes.fieldLevelHelp !== undefined ? this.column.typeAttributes.fieldLevelHelp : true
    };

    return this.innerValueObject;
  }

  getValid = (val) => {
    return val !== undefined ? val : null;
  }

  getObjValid = (val) => {
    return val !== undefined ? this.getDataValue(val, this.row) : null;
  }

  getFieldApiName = () => {
    let fieldApiName;
    if (this.recordApiName && this.column.typeAttributes !== undefined && typeof this.column.typeAttributes.fieldApiName === 'object') {
      fieldApiName = this.getValid(this.column.typeAttributes.fieldApiName[this.recordApiName]);
    }
    else {
      fieldApiName = this.column.typeAttributes !== undefined ? this.getValid(this.column.typeAttributes.fieldApiName) : null;
    }
    return fieldApiName;
  }

  getRecordId = () => {
    let recordId;
    if (this.recordApiName && this.column.typeAttributes !== undefined && typeof this.column.typeAttributes.recordId === 'object') {
      recordId = this.getObjValid(this.column.typeAttributes.recordId[this.recordApiName]);
    }
    else {
      recordId = this.column.typeAttributes !== undefined ? this.getObjValid(this.column.typeAttributes.recordId) : null;
    }
    return recordId;
  }

  getRequired = () => {
    let required;
    if (this.recordApiName && this.column.typeAttributes !== undefined && typeof this.column.typeAttributes.required === 'object') {
      required = this.getValid(this.column.typeAttributes.required[this.recordApiName]);
    }
    else {
      required = this.column.typeAttributes !== undefined ? this.getValid(this.column.typeAttributes.required) : null;
    }
    return required;
  }

  get editModeInner() {
    return (this.column.editable !== undefined && this.column.editable && this.editMode)
  }

  @api
  setEdit(value) {
    this.editMode = value;
    const customForm = this.template.querySelector('c-custom-form-field-template');
    if (customForm) {
      customForm.setEdit(value);
    }
  }

  @api
  setSearchFilter(value) {
    const customLookup = this.template.querySelector('c-custom-lookup-cell');
    if (customLookup) {
      customLookup.setSearchFilter(value);
    }
  }

  @api
  getValue() {
    let value;
    switch (this.columnType) {
      case 'sobject':
        value = this.getCustomFormValue();
        break;
      case 'picklist':
        value = {
          field : this.innerValueObject.fieldPath,
          value : this.getPicklistValue()
        }
        break;
      case 'customLookup':
        value = {
          field : this.innerValueObject.fieldPath,
          value : this.getCustomLookupValue()
        }
        break;
      default:
    }
    return value;
  }

  @api
  isValueChanged() {
    let value;
    switch (this.columnType) {
      case 'sobject': {
        const customForm = this.template.querySelector('c-custom-form-field-template');
        value = customForm ? customForm.isValueChanged() : false;
        break;
      }
      case 'picklist':
        value = true;
        break;
      default:
    }
    return value;
  }

  @api
  isValidField() {
    const customForm = this.template.querySelector('c-custom-form-field-template');
    return customForm ? customForm.isValidField() : true;
  }

  @api
  setFieldValue(value, fieldApiName) {
    if (this.innerFieldName() === fieldApiName) {
      if (this.lookupPreview) {
        const customLookup = this.template.querySelector('c-custom-lookup-preview');
        customLookup.setValue(value);
      }
      if (this.text) {
        const input = this.template.querySelector('lightning-input');
        input.value = value;
      }
    }
  }

  @api
  getColumnDefinition() {
    return this.innerValueObject;
  }

  @api
  isRequiredField() {
    return this.innerValueObject.required;
  }

  innerFieldName = () => {
    if (typeof this.columnFieldName === 'object' && this.recordApiName != null) {
      return this.columnFieldName[this.recordApiName];
    }
    return this.columnFieldName
  }

  getDataValue = (field, obj) => {
    return field !== undefined && obj !== undefined ? field.split('.').reduce((o,i)=>o[i], obj) : null;
  }

  getRecordApiName = (field) => {
    let recordApiName = null;
    if (field !== undefined ) {
      recordApiName = field.includes("__c") ? field : this.getDataValue(field, this.row);
    }
    return recordApiName;
  }

  handleChange() {
    let value;
    switch (this.columnType) {
      case 'picklist':
        value = this.getPicklistValue();
        break;
      case 'customLookup':
        value = this.getCustomLookupValue();
        break;
      case 'checkbox':
        value = this.getCheckboxValue();
        break;
      default:
    }
    this.dispatchEvent(new CustomEvent('selectvalue',
      {
        bubbles: true,
        composed: true,
        detail: {
          value : value,
          fieldApiName : this.innerValueObject.fieldPath}})
    );
  }

  handleLoadCell(event) {
    event.stopPropagation();
    this.dispatchEvent(new CustomEvent('loadcell', {
      detail: {
        ...event.detail,
        id: this.row.Id
      },
      bubbles: true,
      composed: true
    }));
  }

  handleButton() {
    this.dispatchEvent(new CustomEvent('selectaction',
      {
        bubbles: true,
        composed: true,
        detail: {value : this.innerValueObject.fieldName}})
    );
  }

  getCheckboxValue = () =>{
    const inputField = this.template.querySelector('lightning-input');
    return inputField !== undefined && inputField.checked !== undefined ? inputField.checked : null
  }

  getCustomLookupValue = () => {
    const customLookup = this.template.querySelector('c-custom-lookup-cell');
    return customLookup && customLookup.getValue().length > 0 ? customLookup.getValue()[0].id : ''
  }

  getPicklistValue = () => {
    const inputField = this.template.querySelector('lightning-combobox');
    return inputField !== undefined && inputField.value !== undefined ? inputField.value : null
  }

  getCustomFormValue = () => {
    const customForm = this.template.querySelector('c-custom-form-field-template');
    return customForm ? customForm.getValue() : ''
  }

}