import { LightningElement, api } from "lwc";
import { keywords } from 'c/lookupKeywords';
import { CommonUtils, LabelService } from "c/utils";
import { CashDisbursement, CashReceipt, BankDeposit, JournalEntryLine, BankTransaction } from "c/sobject";

export default class BdcUnmatchedDrawerTemplate extends LightningElement {
  @api columns;
  @api row;
  @api isEditMode;
  innerRow;
  defaultRow;
  labels = LabelService;

  selectMatchSection = false;
  selectCreateSection = false;
  valueRadio = '';
  possibleMatch = false;
  optionsRadio = [
    { label: LabelService.commonAdd, value: 'createRecord', checked: false},
    { label: LabelService.commonMatch, value: 'selectMath', checked: true},
  ];
  isProjectTaskFilterSet = false;

  cd = new CashDisbursement();
  cr = new CashReceipt();
  bd = new BankDeposit();
  jel = new JournalEntryLine();
  bt = new BankTransaction();

  @api
  getCustomCellComponents() {
    return this.template.querySelectorAll('c-custom-cell');
  }

  @api
  getInnerRow() {
    return this.innerRow;
  }

  get radioId() {
    return this.row.Id + '1';
  }

  get drawerButtonLabel() {
    return this.selectMatchSection ? LabelService.commonMatch : LabelService.commonAdd;
  }

  connectedCallback() {
    this.setDefaultRow();
    this.setPossibleMatch();
    this.setSelectedRecordValues();
  }

  renderedCallback() {
    if (!this.isProjectTaskFilterSet) {
      this.setProjectTypeFilter();
      this.isProjectTaskFilterSet = true;
    }
  }

  setPossibleMatch() {
    if (this.row !== undefined && this.row.possibleMatches.length > 0) {
      this.selectMatchSection = true;
      this.valueRadio = 'selectMath';
      this.possibleMatch = true;
    }
    else {
      this.selectCreateSection = true;
    }
  }

  setDefaultRow() {
    this.defaultRow = CommonUtils.copyObject(this.row);
    this.innerRow = CommonUtils.copyObject(this.row);
    let proxyObj = CommonUtils.copyObject(this.row.defaultAppliedProxyObj);
    proxyObj.attributes = this.row.proxyObj.obj.attributes;
    this.defaultRow.proxyObj.obj = proxyObj;
    this.defaultRow.selectedType = this.getSelectedMatchType(this.row.proxyObj);
  }

  setSelectedRecordValues() {
    if (this.possibleMatch) {
      let selectedMatch = this.oldSelectedMatch();
      this.setMatchedValueEvents(selectedMatch);
      this.rowChangeEvent(this.innerRow);
      this.fireChangeActionName("MATCH");
      this.fireChangeActionState(false);
    }
    else {
      this.fireChangeActionState(false);
    }
  }

  handleSelectValue({detail}){
    if (detail.value === 'createRecord') {
      this.innerRow = this.defaultRow;
      this.selectCreateSection = true;
      this.selectMatchSection = false;
      this.setDefaultValueEvents();
      this.innerRow.unmatchedActionName = this.selectCreateSection ? "ADD" : this.innerRow.unmatchedActionName;
      this.rowChangeEvent(this.innerRow);
      this.fireChangeActionState(false);
    }
    else if (detail.value === 'selectMath') {
      this.selectCreateSection = false;
      this.selectMatchSection = true;
      let oldSelectedMatch = this.oldSelectedMatch();
      this.setMatchedValueEvents(oldSelectedMatch);
      this.fireChangeActionName("MATCH");
      this.fireChangeActionState(false);
    }
  }

  handleSelectMatch(event) {
    let selectedValue = event.target.value;
    let selectedMatch = this.selectedMatch(selectedValue);
    let oldSelectedMatch = this.oldSelectedMatch();
    selectedMatch.checked = true;
    oldSelectedMatch.checked = false;
    this.setMatchedValueEvents(selectedMatch);
    this.innerRow.selectedType = this.getSelectedMatchType(selectedMatch.possibleMatch)
    this.rowChangeEvent(this.innerRow);
    this.fireChangeActionName("MATCH");
    this.fireChangeActionState(false);
  }

  getAccountName(type) {
    let accountName;
    switch (type) {
      case CashDisbursement.objectApiName :
        accountName = this.cd.vendor;
        break;
      case CashReceipt.objectApiName :
      case JournalEntryLine.objectApiName :
        accountName = this.cr.account;
        break;
      default:
    }
    return accountName;
  }

  getGLAccountName(type) {
    let glAccountName;
    switch (type) {
      case CashDisbursement.objectApiName :
        glAccountName = this.cd.debit_gl_account;
        break;
      case CashReceipt.objectApiName :
        glAccountName = this.cr.credit_gl_account;
        break;
      case JournalEntryLine.objectApiName :
        glAccountName = this.jel.gl_account;
        break;
      case BankDeposit.objectApiName :
        glAccountName = this.bd.bank_account;
        break;
      default:
    }
    return glAccountName;
  }

  setDefaultValueEvents() {
    this.handleChangeValue(this.defaultRow.proxyObj.obj[this.getAccountName(this.defaultRowType())], "proxyObj.obj." + this.getAccountName(this.rowType()));
    this.handleChangeValue(this.defaultRow.proxyObj.obj[this.cr.cash_flow_category], "proxyObj.obj." + this.cr.cash_flow_category);
    this.handleChangeValue(this.defaultRow.proxyObj.obj[this.getGLAccountName(this.defaultRowType())], "proxyObj.obj." + this.getGLAccountName(this.rowType()));
    this.handleChangeValue(this.defaultRow.selectedType, "selectedType");
    this.handleChangeValue(this.defaultRow.proxyObj.obj[this.cr.description], "proxyObj.obj." + this.cr.description);
  }

  setMatchedValueEvents(selectedMatch) {
    this.handleChangeValue(selectedMatch.possibleMatch.obj[selectedMatch.accountFieldName], "proxyObj.obj." + this.getAccountName(this.rowType()));
    this.handleChangeValue(selectedMatch.possibleMatch.obj[this.cr.cash_flow_category], "proxyObj.obj." + this.cr.cash_flow_category);
    this.handleChangeValue(selectedMatch.possibleMatch.obj[selectedMatch.glAccountFieldName], "proxyObj.obj." + this.getGLAccountName(this.rowType()));
    this.handleChangeValue(this.getSelectedMatchType(selectedMatch.possibleMatch), "selectedType");
    this.handleChangeValue(selectedMatch.possibleMatch.obj[selectedMatch.descriptionFieldName], "proxyObj.obj." + this.cr.description);
  }

  getSelectedMatchType(possibleMatch) {
    let type;
    switch (possibleMatch.sobjType) {
      case CashDisbursement.objectApiName :
        type = 'Cash Disbursement';
        break;
      case CashReceipt.objectApiName :
        if (possibleMatch.obj[this.cr.amount] < 0) {
          type = 'Refund Cash Receipt';
        }
        else {
          type = 'Cash Receipt';
        }
        break;
      case JournalEntryLine.objectApiName :
        if (this.innerRow.bt.obj[this.bt.base_type].toLowerCase() === 'credit') {
          type = 'Journal Entry Debit';
        }
        else if (this.innerRow.bt.obj[this.bt.base_type].toLowerCase() === 'debit') {
          type = 'Journal Entry Credit';
        }
        break;
      case BankDeposit.objectApiName :
        type = 'Bank Deposit';
        break;
      default:
    }
    return type;
  }

  fireChangeActionName(action) {
    this.handleChangeValue(action, "unmatchedActionName");
  }

  fireChangeActionState(state) {
    this.handleChangeValue(state, "actionDisabled");
  }

  setProjectTypeFilter() {
    let projectTask;
    let project;
    this.customCellElements().forEach(item => {
      if (item.getColumnDefinition().fieldPath === 'proxyObj.obj.' + this.cr.project_task) {
        projectTask = item;
      }
      if (item.getColumnDefinition().fieldPath === 'proxyObj.obj.' + this.cr.project) {
        project = item;
      }
    });

    if (project && projectTask) {
      let filter = {
        type: keywords.type.ID,
        field: this.cr.project,
        op: keywords.op.EQUAL,
        val: project.getValue().value
      }

      projectTask.setSearchFilter(filter);
    }
  }

  changeType(value) {
    let proxy = this.innerRow.proxyObj;
    this.innerRow.proxyObj = this.innerRow.shadowProxyObj;
    this.innerRow.shadowProxyObj = proxy;
    this.innerRow.selectedType = value;
    this.innerRow.unmatchedActionName = this.selectCreateSection ? "ADD" : this.innerRow.unmatchedActionName;
    this.rowChangeEvent(this.innerRow);
    if (this.selectCreateSection) {
      this.fireChangeActionName("ADD");
      this.fireChangeActionState(false);
    }
  }

  handleComponentChangeValue(event) {
    const detail = event.detail;
    if (detail.fieldApiName === 'selectedType') {
      this.changeType(detail.value);
    }
    if (detail.fieldApiName === 'proxyObj.obj.' + this.cr.project) {
      this.setProjectTypeFilter();
    }
    this.validateRequiredField();
  }

  validateRequiredField() {
    let valid = true;
    if (this.innerRow.details.details !== "") {
      this.customCellElements().forEach(item => {
        if (item.isRequiredField() && (item.getValue().value == null || item.getValue().value === "")) {
          valid = false;
        }
      });
      if (valid) {
        this.innerRow.details.details = "";
        let rowCopy = CommonUtils.copyObject(this.innerRow);
        if (rowCopy.details) {
          rowCopy.details.details = "";
        }
        this.rowChangeEvent(rowCopy);
        this.fireChangeActionState(false);
      }
    }
  }

  handleChangeValue(value, fieldApiName) {
    this.dispatchEvent(new CustomEvent('selectvalue',
      {
        bubbles: true,
        composed: true,
        detail: {
          value : value,
          fieldApiName : fieldApiName}})
    );
  }

  handleButton() {
    this.dispatchEvent(new CustomEvent('selectaction',
      {
        bubbles: true,
        composed: true,
        detail: {value : this.selectMatchSection ? 'match' : 'add'}})
    );
  }

  rowChangeEvent(detail) {
    this.dispatchEvent(new CustomEvent('rowchange',
      {
        bubbles: true,
        composed: true,
        detail: detail
      })
    );
  }

  oldSelectedMatch = () => this.innerRow.possibleMatches.find(item => item.checked === true);
  selectedMatch = (selectedValue) => this.innerRow.possibleMatches.find(item => item.possibleMatch.obj.Name === selectedValue);

  defaultRowType = () => this.defaultRow.proxyObj.sobjType;
  rowType = () => this.row.proxyObj.sobjType;

  customCellElements = () => this.template.querySelectorAll('c-custom-cell');

}