import { LightningElement, api, track } from "lwc";
import { WindowUtils, LabelService } from "c/utils";
import { BankReconciliation } from "c/sobject";
import { getFieldValue } from 'lightning/uiRecordApi';
import Labels from "./labels";

export default class BankRecFilter extends LightningElement {
  
  labels = {...LabelService, ...Labels};
  @api bankRec;
  @track searchName;
  @track dateStart;
  @track dateEnd;
  @track type;
  @track state = 'All';
  @track amountMin;
  @track amountMax;
  br = BankReconciliation;
  currentClientX = 0;
  currentClientY = 0;
  showSearchNameFilter = false;
  showDateStartFilter = false;
  showDateEndFilter = false;
  showTypeFilter = false;
  showAmountMinFilter = false;
  showAmountMaxFilter = false;
  showClearedStateFilter = false;
  showUnclearedStateFilter = false;

  get typeOptions() {
    let isBank = getFieldValue(this.bankRec, this.br.type1) === 'Bank';
    return [
      { label: isBank ? LabelService.commonPayment : LabelService.commonCharge, value: isBank ? 'Payment' : 'Charge' },
      { label: isBank ? LabelService.commonDeposits : LabelService.commonPayment, value: isBank ? 'Deposit' : 'Payment' },
    ];
  }

  get stateOptions() {
    return [
      { label: LabelService.commonAll, value: 'All' },
      { label: Labels.INF_CLEARED_ONLY, value: 'Cleared' },
      { label: Labels.INF_UNCLEARED_ONLY, value: 'Uncleared' },
    ];
  }

  @api
  showFilterPopover(parentComponent) {
    let filterPopover = this.popover();
    let coordinates = WindowUtils.getXYCoordinates(parentComponent, this.currentClientX, this.currentClientY, 30, -180);
    WindowUtils.setElementAbsolutePosition(filterPopover, coordinates);
  }

  @api
  setCoordinates(valX, valY) {
    this.currentClientX = valX;
    this.currentClientY = valY;
  }

  handleFilterApply() {
    if (this.type) {
      this.showTypeFilter = true;
    }
    this.validateState();
    if (this.validateDateRanges() && this.validateAmount()) {
      if (this.searchName) {
        this.showSearchNameFilter = true;
      }
      if (this.dateStart) {
        this.showDateStartFilter = true;
      }
      if (this.dateEnd) {
        this.showDateEndFilter = true;
      }
      if (this.type && this.amountMin) {
        this.showAmountMinFilter = true;
      }
      if (this.type && this.amountMax) {
        this.showAmountMaxFilter = true;
      }
      this.valueChangeHandler();
      this.handleFilterClose();
    }
  }

  validateState() {
    if (this.state === 'All') {
      this.showClearedStateFilter = true;
      this.showUnclearedStateFilter = true;
    }
    else if (this.state === 'Cleared') {
      this.showClearedStateFilter = true;
      this.showUnclearedStateFilter = false;
    }
    else if (this.state === 'Uncleared') {
      this.showClearedStateFilter = false;
      this.showUnclearedStateFilter = true;
    }
  }

  validateDateRanges() {
    let isValid = false;
    if (this.dateStart && this.dateEnd && this.dateStart > this.dateEnd) {
      this.dateEndCmp().setCustomValidity(LabelService.errorEndDateMustBeGreaterThanStart);
    } else {
      this.dateEndCmp().setCustomValidity("");
      isValid = true;
    }
    this.dateEndCmp().reportValidity();
    return isValid;
  }

  validateAmount() {
    let isValid = false;
    if (this.amountMin && this.amountMax && parseFloat(this.amountMin) > parseFloat(this.amountMax)) {
      this.amountMaxCmp().setCustomValidity(LabelService.errorMaxMustBeGreaterThanMin);
    }
    else if ((this.amountMin || this.amountMax) && this.type === undefined) {
      if (this.amountMin) {
        this.amountMinCmp().setCustomValidity(Labels.ERR_FILTER_BY_TYPE_FOR_AMOUNT_FILTER);
      }
      if (this.amountMax) {
        this.amountMaxCmp().setCustomValidity(Labels.ERR_FILTER_BY_TYPE_FOR_AMOUNT_FILTER);
      }
    }
    else {
      this.amountMinCmp().setCustomValidity("");
      this.amountMaxCmp().setCustomValidity("");
      isValid = true;
    }
    this.amountMinCmp().reportValidity();
    this.amountMaxCmp().reportValidity();
    return isValid;
  }

  handleStartDateChange({ detail }) {
    this.dateStart = detail.value;
  }

  handleEndDateChange({ detail }) {
    this.dateEnd = detail.value;
  }

  handleTypeChange({ detail }) {
    this.type = detail.value;
  }

  handleStateChange({ detail }) {
    this.state = detail.value;
  }

  handleSearchNameChange({ detail }) {
    this.searchName = detail.value;
  }

  handleMinAmountChange({ detail }) {
    this.amountMin = detail.value;
  }

  handleMaxAmountChange({ detail }) {
    this.amountMax = detail.value;
  }

  handleSearchNameResultClose() {
    this.showSearchNameFilter = false;
    this.searchName = undefined;
    this.valueChangeHandler();
  }

  handleDateStartResultClose() {
    this.showDateStartFilter = false;
    this.dateStart = undefined;
    this.valueChangeHandler();
  }

  handleDateEndResultClose() {
    this.showDateEndFilter = false;
    this.dateEnd = undefined;
    this.valueChangeHandler();
  }

  handleTypeResultClose() {
    this.showTypeFilter = false;
    this.type = undefined;
    this.handleAmountMinResultClose()
    this.handleAmountMaxResultClose()
  }

  handleAmountMinResultClose() {
    this.showAmountMinFilter = false;
    this.amountMin = undefined;
    this.valueChangeHandler();
  }

  handleAmountMaxResultClose() {
    this.showAmountMaxFilter = false;
    this.amountMax = undefined;
    this.valueChangeHandler();
  }

  handleClearedStateResultClose() {
    this.showClearedStateFilter = false;
    this.state = this.showUnclearedStateFilter ? 'Uncleared' : 'All';
    this.valueChangeHandler();
  }

  handleUnclearedStateResultClose() {
    this.showUnclearedStateFilter = false;
    this.state = this.showClearedStateFilter ? 'Cleared' : 'All';
    this.valueChangeHandler();
  }

  valueChangeHandler() {
    this.dispatchEvent(new CustomEvent('valuechange', {
      cancelable: true,
      detail: {
        searchName: this.searchName,
        type: this.type,
        state: this.state,
        dateStart: this.dateStart,
        dateEnd: this.dateEnd,
        amountMin: this.type !== undefined ? this.amountMin : undefined,
        amountMax: this.type !== undefined ? this.amountMax : undefined,
        validFilter: this.state !== undefined || this.type !== undefined || this.dateStart !== undefined || this.dateEnd !== undefined
      }
    }));
  }

  handleFilterClose() {
    this.popover().setAttribute('style', 'display:none;');
  }

  popover = () => this.template.querySelector('[data-id="filter-popover"]');
  amountMaxCmp = () => this.template.querySelector('.amount-max');
  amountMinCmp = () => this.template.querySelector('.amount-min');
  dateEndCmp = () => this.template.querySelector('.date-end');
}