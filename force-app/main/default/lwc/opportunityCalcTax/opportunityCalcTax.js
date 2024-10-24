import {api, LightningElement, track, wire} from 'lwc';
import { Constants, LabelService, KnowledgeBase, NotificationService } from "c/utils";
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import {Address, Ledger, OpportunityLineItem} from "c/sobject";
import { CloseActionScreenEvent } from 'lightning/actions';
import retrieveData from '@salesforce/apex/OpportunityCalcTaxController.retrieveData';
import retrieveHeaderData from '@salesforce/apex/OpportunityCalcTaxController.retrieveHeaderData';
import calcTax from '@salesforce/apex/OpportunityCalcTaxController.calcTax';
import CURRENCY from '@salesforce/i18n/currency';
import { keywords } from 'c/lookupKeywords';
import { refreshApex } from '@salesforce/apex';
import Labels from './labels';

const GLOBAL_ERROR_CODES = new Set(['NO_ACCOUNT_ERROR', 'NO_OPPORTUNITY_PRODUCT_LINE']);

export default class OpportunityCalcTax extends LightningElement {

  labels = {...LabelService, ...Labels};
  @api recordId;
  @api ltngOut = false;
  @api callBacks;

  @track error = {};
  @track totalRecords;

  @track headerData;
  @track taxMethod;

  address = Address;
  ledger = Ledger;
  opportunityLineItem = new OpportunityLineItem();

  @track data = {};
  showSpinner = true;
  knowledgeBase = {
    iconName: 'standard:question_feed',
    iconAltText: LabelService.commonKnowledgeBase,
    url: KnowledgeBase.opportunityCalcTax
  };
  currencyCode = CURRENCY;
  isMultiCurrencyEnabled = false;

  ledgerRetrieveFields = {
    [this.ledger.objectApiName]: [
      this.ledger.taxSetting.fieldApiName,
      this.ledger.taxSettingTaxMethod.fieldApiName
    ]
  };

  ledgerMessages = {
    requiredFieldMissingMessage: Labels.INF_LEDGER_VALUE_REQUIRED_TO_ESTIMATE_TAXES
  };

  ledgerSearchFilter = {
    type: keywords.type.STRING,
    field: Ledger.type1.fieldApiName,
    op: keywords.op.IN,
    val: ['Transactional']
  };

  get modalSize() {
    return this.ltngOut && 'large' || 'customLarge';
  }

  get isCalcTaxBlocked() {
    return (this.error && this.error.globalErrors && this.error.globalErrors.length)
        || (this.error && this.error.localErrors && this.error.localErrors.length)
        || this.showSpinner;
  }

  get isAvaTaxHeaderLevel() {
    return this.taxMethod?.methodName === Constants.TAX_SETTINGS.TAX_METHOD.AVA_TAX && this.headerData && this.headerData.isHeaderLevelPost;
  }

  get isAvaTaxLineLevel() {
    return this.taxMethod?.methodName === Constants.TAX_SETTINGS.TAX_METHOD.AVA_TAX && this.headerData && !this.headerData.isHeaderLevelPost;
  }

  get isNativeTaxHeaderLevel() {
    return this.taxMethod?.methodName === Constants.TAX_SETTINGS.TAX_METHOD.NATIVE_SALES_TAX && this.headerData && this.headerData.isHeaderLevelPost;
  }

  get isNativeTaxLineLevel() {
    return this.taxMethod?.methodName === Constants.TAX_SETTINGS.TAX_METHOD.NATIVE_SALES_TAX && this.headerData && !this.headerData.isHeaderLevelPost;
  }

  get isAvalaraTax () {
    return this.isAvaTaxHeaderLevel || this.isAvaTaxLineLevel;
  }

  get isHeaderLevelPost () {
    return this.headerData.isHeaderLevelPost;
  }

  get isLineLevelPost () {
    return !this.headerData.isHeaderLevelPost;
  }

  get isLines4Display() {
    return this.validateLedgerLookup() && this.validateTaxMethod();
  }

  get headerSubtotal () {
    return (this.selectedLedgerId && this.data && this.data.sourceObj && this.data.sourceObj.Amount) || 0;
  }

  get headerEstimatedTaxAmount () {
    return (this.selectedLedgerId && this.data && this.data.sourceObj && this.data.sourceObj[this.opportunityLineItem.tax_amount]) || 0;
  }

  get headerEstimatedTotal () {
    return this.headerSubtotal + this.headerEstimatedTaxAmount;
  }

  get isGlobalErrors() {
    return this.error.globalErrors && this.error.globalErrors.length;
  }

  get isLocalErrors() {
    return !this.isGlobalErrors && this.error.localErrors && this.error.localErrors.length;
  }

  @wire(retrieveHeaderData, {recordId: '$recordId'})
  fetchHeaderData(result) {
    this.wiredHeaderData = result;
    result?.data && (
        refreshApex(this.wiredHeaderData),
        this.headerData = result.data,
        this.selectedLedgerId = this.headerData.ledgerId,
        this.isMultiCurrencyEnabled = !!this.headerData?.record?.currencyIsoCode,
        this.currencyCode = this.headerData?.record?.currencyIsoCode,
        this.fetchData(this.headerData.ledgerId)
    );
  }

  fetchData(ledgerId, previewParamsByIds) {
    this.previewParamsByIds = {...this.previewParamsByIds, ...previewParamsByIds};
    this.showSpinner = true;
    retrieveData({params: { opportunityId: this.recordId, ledgerId: ledgerId }, previewParamsByIds: this.previewParamsByIds})
        .then((result) => {
          const sourceDocResult = result?.taxServiceResult?.sourceDocs[0];
          if (sourceDocResult?.isSuccess) {
            this.data = result?.taxServiceResult?.sourceDocs[0];
            this.isMultiCurrencyEnabled = this.data?.sourceObj?.hasOwnProperty("CurrencyIsoCode");
            this.currencyCode =  this.data?.sourceObj?.hasOwnProperty("CurrencyIsoCode") ? this.data.sourceObj.CurrencyIsoCode : this.currencyCode;

          } else if (sourceDocResult?.errors) {
            this.error.globalErrors = [...sourceDocResult?.errors].filter(item => GLOBAL_ERROR_CODES.has(item.code));
            this.error.localErrors = [...sourceDocResult?.errors]
                .filter(item => !GLOBAL_ERROR_CODES.has(item.code))
                .map(item => item.message);
          }
        })
        .catch(e => this.error.localErrors = [e?.body?.message])
        .finally(() => {this.showSpinner = false})
  }
  closeQuickAction() {
    this.dispatchEvent(new CloseActionScreenEvent());
    this.callBacks && this.callBacks.backToRecord && this.callBacks.backToRecord();
  }

  openModal() {
    const opportunityCalcTaxModal = this.template.querySelector('c-modal-popup-base[data-id="opportunityCalcTaxModal"]');
    opportunityCalcTaxModal && opportunityCalcTaxModal.openModal();
  }

  ledgerIdByLookupContainer() {
    const ledgerLookup = this.template.querySelector('[data-id="lookup-ledger"]');
    return ledgerLookup && ledgerLookup.getSelection() && ledgerLookup.getSelection()[0] && ledgerLookup.getSelection()[0].id;
  }

  calculateTax() {
    this.validateLedgerLookup() && (
      this.showSpinner = true,
      calcTax({params: { opportunityId: this.recordId, ledgerId: this.ledgerIdByLookupContainer() }, previewParamsByIds: this.previewParamsByIds})
        .then((result) => {

          if (!result.errors || !result.errors.length) {
            NotificationService.displayToastMessage(
                this,
                LabelService.taxEstimateSuccessText,
                LabelService.commonSuccess,
                'success'
            );
            const lineIds = this.previewParamsByIds && Object.keys(this.previewParamsByIds);
            const records = [...[{recordId: this.recordId}], ...lineIds.map(lineId => ({recordId: lineId}))];
            getRecordNotifyChange(records);
            this.closeQuickAction();
          } else {
            this.error.localErrors = [...result?.errors].map(item => !GLOBAL_ERROR_CODES.has(item.code) && item.message);
          }
        })
        .catch(e => this.error.localErrors = [e?.body?.message])
        .finally(() => {this.showSpinner = false})
    )
  }

  handleSelectionChange(event) {
    this.previewParamsByIds = {};
    this.taxMethod = event.detail && {
      name: event.detail[this.ledger.taxSettingTaxMethod.fieldApiName],
      methodName: event.detail[this.ledger.taxSettingTaxMethod.fieldApiName],
      id: event.detail[this.ledger.taxSetting.fieldApiName],
      url: event.detail[this.ledger.taxSetting.fieldApiName] && ('/' + event.detail[this.ledger.taxSetting.fieldApiName])
    };

    this.selectedLedgerId = event.detail && (event.detail.recordId || event.detail.id);

    this.validateTaxMethod() && event.type !== 'initvalueloaded' && this.selectedLedgerId && (
      this.data = undefined,
      this.showSpinner = true,
      this.fetchData(this.selectedLedgerId)
    );
  }

  validateTaxMethod() {
    let isValid = true;
    if (this.validateLedgerLookup() && (!this.taxMethod || !this.taxMethod.id)) {
      this.error.localErrors = null;
      this.error.taxMethod = {message: Labels.COMMON_ERR_TAX_SETTING_LEDGER};
      isValid = false;
    } else {
      this.error.taxMethod = null;
    }
    return isValid;
  }

  validateLedgerLookup() {
    let isValid = true;
    const ledgerLookup = this.template.querySelector('[data-id="lookup-ledger"]');
    ledgerLookup && (isValid = ledgerLookup.reportValidity());
    !isValid && !this.selectedLedgerId && (this.error.localErrors = null);
    return isValid;
  }

  handleTaxGroupChange(event) {
    this.fetchData(this.ledgerIdByLookupContainer(), event.detail);
  }
}