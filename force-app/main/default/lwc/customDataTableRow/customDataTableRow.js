import { LightningElement,api } from "lwc";
import { CommonUtils, LabelService } from "c/utils";
import Labels from './labels';


export default class CustomDataTableRow extends LightningElement {
  labels = {...LabelService, ...Labels};
  @api row;
  @api additional = false;
  @api columns = [];
  @api additionalColumns = [];
  @api defaultEdit = false;
  @api actions;
  @api isEditMode = false;
  @api isEditModeAllComponents = false;
  @api additionalSectionTemplateName = '';
  showAdditional = false;

  currentIcon = "chevronright";
  resultRow;
  currentStyle;

  get iconLink() {
    return "utility:" + this.currentIcon;
  }

  get showDrawer() {
    return this.additionalColumns.length > 0;
  }

  get cancelButton() {
    return !this.defaultEdit && this.actions.showCancel;
  }

  @api
  expandCollapsDrawer(value) {
    this.showAdditional = value;
  }

  @api
  getExpandCollapsDrawerValue() {
    return this.showAdditional;
  }

  @api
  cancelAction() {
    this.handleCancelAction();
  }

  @api
  setEditMode(value) {
    this.isEditMode = value;
  }

  @api
  setEditAllMode(value) {
    this.isEditMode = value;
    this.isEditModeAllComponents = value;
  }

  @api
  saveAction(isEdit) {
    this.resultRow = CommonUtils.copyObject(this.row);
    if (isEdit) {
      this.resultRow.isEdit = isEdit;
    }
    this.getValues();
    this.row = this.resultRow;
    return this.row;
  }

  @api
  setActionIcon(value) {
    this.currentIcon = value;
  }

  @api
  getRowFromTemplate() {
    return this.getTemplateInnerRow();
  }

  @api
  getRowId() {
    return this.row.Id;
  }

  @api
  componentChangeValue(value, fieldApiName) {
    let elements = this.getCustomCellComponents();
    if (elements) {
      elements.forEach((element) => {
        element.setFieldValue(value, fieldApiName)
      });

      let tempRow = CommonUtils.copyObject(this.row);
      CommonUtils.setDataValue(fieldApiName, tempRow, value);
      this.row = tempRow;
    }
  }

  @api
  allFieldsValid() {
    let isValid = true;
    let elements = this.getCustomCellComponents();
    if (elements) {
      elements.forEach((element) => {
        if (!element.isValidField()) {
          isValid = element.isValidField();
        }
      });
    }
    return isValid;
  }

  @api
  updateRow(value) {
    let tempRow = {...CommonUtils.copyObject(this.row), ...value}
    this.row = tempRow;
  }

  connectedCallback() {
    this.setDefaultEdit();
  }

  setDefaultEdit() {
    if (this.defaultEdit) {
      this.isEditMode = true;
      this.isEditModeAllComponents = true;
    }
  }

  getCustomCellComponents() {
    let elements;
    let container = this.template.querySelector('c-drawer-template-container');
    if (this.additional && container) {
      elements = container.getCurrentTemplate().getCustomCellComponents();
    }
    else if (!this.additional) {
      elements = this.template.querySelectorAll('c-custom-cell');
    }
    return elements;
  }

  getTemplateInnerRow() {
    let innerRow;
    let container = this.template.querySelector('c-drawer-template-container');
    if (container) {
      innerRow = container.getCurrentTemplate().getInnerRow();
    }
    return innerRow;
  }

  handleSectionAction(event) {
    this.currentIcon = this.currentIcon === "chevronright" ? "chevrondown" : "chevronright";
    event.preventDefault();
    this.dispatchEvent(new CustomEvent('sectionaction', { detail: this.row.Id }));
  }

  handleCancelAction() {
    let elements = this.getCustomCellComponents();
    if (elements) {
      if (elements) {
        elements.forEach((element) => {
          element.setEdit(false);
        });
      }
    }

    this.isEditMode = false;
    this.isEditModeAllComponents = false;
    this.dispatchEvent(new CustomEvent('editallaction', { detail: {id : this.row.Id, mode: false}}));
  }

  getValues() {
    let elements = this.getCustomCellComponents();
    if (elements) {
      elements.forEach((element) => {
        this.setRowObjectValue(element);
      });
      this.isEditMode = false;
    }
  }

  setRowObjectValue(element) {
    let data = element.getValue();
    if (element.isValueChanged() && data.value !== undefined && data.value != null) {
      CommonUtils.setDataValue(data.field, this.resultRow, data.value);
      this.resultRow.isEdit = true;
    }
  }

  handleAction(event) {
    let selectedAction = event.target.dataset.action;
    this.dispatchEvent(new CustomEvent('rowaction', { detail: {id : this.row.Id, action : selectedAction}}));
  }

  handleCustomAction(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.dispatchEvent(new CustomEvent('rowaction', { detail: {id : this.row.Id, action : detail.value}}));
  }

  handleComponentChangeValue(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.dispatchEvent(new CustomEvent('valuechange', { detail: {id : this.row.Id, value: detail.value, fieldApiName: detail.fieldApiName}}));
  }

  handleTemplateRowChange(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.dispatchEvent(new CustomEvent('templaterowchange', { detail: {id : this.row.Id, value : detail}}));
  }

  handleComponentEditAction(event) {
    event.stopPropagation();
    this.isEditMode = true;
    this.dispatchEvent(new CustomEvent('sectioneditaction', { detail: {id : this.row.Id, mode: true}}));
  }

}