import { api,track,wire } from 'lwc';
import { LabelService, NotificationService, KnowledgeBase } from 'c/utils';
import Wizard from 'c/wizard';
import getFormData from '@salesforce/apex/CardknoxAccountBoardingFormHelper.getFormData';
import submitForm from '@salesforce/apex/CardknoxAccountBoardingFormHelper.submitForm';
import { states, country } from "./addressDetails";
import { labels } from "./labels";

const STEP_1 = {name: labels.step1, id: 'step1'};
const STEP_2 = {name: labels.step2, id: 'step2'};
const STEP_3 = { name: labels.step3, id: 'step3' };
const STEP_4 = { name: labels.step4, id: 'step4' };

export default class CardknoxAccountBoardingForm extends Wizard {
    @api recordId;
    @track formData = {};
    @track showContent = false;
    @track spinnerClass = 'slds-show';
    currentStep = { ...STEP_1 };
    labels = { ...labels, ...LabelService };
    helpURL = KnowledgeBase.accountBoardingScreenHelp;
    stateList = states;
    countryList = country;

    pathItems = [
        { ...STEP_1 },
        { ...STEP_2},
        { ...STEP_3 },
        { ...STEP_4 }
    ]
    @wire(getFormData)
    formDataResponse({data,error}) {
        if (data) {
            this.formData = Object.assign({}, data);
            this.spinnerClass = 'slds-hide';
        } else if (error) {
            console.error(error);
            this.spinnerClass = 'slds-hide';
        }
    }

    @api
    showComp() {
        this.showContent = true;
    }
    get modalHeader() {
        return this.isStep4Active ? this.labels.agreementFormHeader : this.labels.modalHeader;
    }
    get isStep1Active() {
        return this.currentStep.id === 'step1';
    }
    get isStep2Active() {
        return this.currentStep.id === 'step2';
    }
    get isStep3Active() {
        return this.currentStep.id === 'step3';
    }
    get isStep4Active() {
        return this.currentStep.id === 'step4';
    }
    get brandAction() {
        return this.isStep4Active ? this.labels.submit : this.labels.commonNext;
    }
    get neutralAction() {
        return this.isStep1Active ? this.labels.commonCancel : this.labels.commonBack;
    }
    get isDisable() {
        return this.formData && !this.formData['token'] && this.isStep4Active ? true : false;
    }
    get signerInfo() {
        if (!this.formData.signerInfo) {
            this.formData.signerInfo = [{}];
        }
        return this.formData.signerInfo;
    }
    get canAddSigner() {
        return this.formData.signerInfo && this.formData.signerInfo.length !== 4 ? true : false;
    }
    handleCancelButton(evt) {
        if (evt.target.label === this.labels.commonCancel) {
            this.dispatchEvent(new CustomEvent('cancel'));
        } else {
            this.handleBackButton();
        }
    }
    handleBackButton() {
        this.goBack({});
    }
    handleActionButton(evt) { 
        if (evt.target.label === this.labels.commonNext) {
            this.goNext();
        } else {
            this.submitForm();
        }
    }
    handleAgreementToken(evt) {
        this.formData['token'] = evt.detail.token;
    }
    async submitForm() {
        if (!this.formData['token']) {
            this.showToast(this.labels.crdError, this.labels.commonToastErrorTitle, 'error');
            return;
        }
        try {   
            this.spinnerClass = 'slds-show';
            await submitForm({ jsonString: JSON.stringify(this.formData) });
            this.showToast(this.labels.crdSuccess, this.labels.commonToastSuccessTitle, 'success');
            this.dispatchEvent(new CustomEvent('cancel'));
        } catch (error) {
            this.showToast(error.body.message, this.labels.commonToastErrorTitle, 'error');
        } finally {
            this.spinnerClass = 'slds-hide';
        }
    }
    handleDataChange(evt) {
        if (evt.detail.type === 'checkbox') {
            this.formData[evt.detail.name] = evt.detail.checked;
        } else if (evt.detail.index !== undefined) {
            this.formData.signerInfo[evt.detail.index][evt.detail.name] = evt.detail.value;
        }else {
            this.formData[evt.detail.name] = evt.detail.value;
        }
    }
    handleAddressSameCheckboxClick(evt) {
        if (evt.detail.checked === true) {
            this.formData['maStreet'] = this.formData['baStreet'];
            this.formData['maCity'] = this.formData['baCity'];
            this.formData['maState'] = this.formData['baState'];
            this.formData['maZip'] = this.formData['baZip'];
            this.formData['maCountry'] = this.formData['baCountry'];
        }
    }
    handleItemClick(event) {
        const ONE_STEP = 1;
        const gotoPathItemId = event.detail.value;

        const gotoPathItemIndex = this.pathItems.findIndex(item => item.id === gotoPathItemId);
        const currentStepIndex = this.pathItems.findIndex(item => item.id === this.currentStep.id);

        gotoPathItemIndex > currentStepIndex && gotoPathItemIndex - currentStepIndex === ONE_STEP &&
            this.goNext();

        gotoPathItemIndex < currentStepIndex &&
            this.goBack({}, this.pathItems[gotoPathItemIndex]);
    }
    goNext() {
        super.goNext(() => { this.goToPathItem(this.currentStep.id); });
        this.resetTokenValue();
    }

    goBack(event, prevStep) {
        super.goBack(prevStep, () => { this.goToPathItem(this.currentStep.id); });
        this.resetTokenValue();
    }
    resetTokenValue() {
        this.formData['token'] = null;
    }
    goToPathItem(pathItemId) {
        const path = this.template.querySelector('c-path');
        path && path.goToItem(pathItemId);
    }
    showToast(message,title,variant) {
        NotificationService.displayToastMessage(this, message, title, variant);
    }
    handleAddSigner() {
        this.formData.signerInfo.push({});
    }
    handleDeleteSigner(evt) {
        this.formData.signerInfo.splice(evt.detail.signerIndex, 1);
    }
}