import { api,track } from 'lwc';
import WizardItem from 'c/wizardItem';
import { handleDataChange,isValid } from "c/cardknoxDataChangeHelper";
export default class CardknoxStepSignerInfo extends WizardItem {
    @api formData;
    @api signer;
    @api labels;
    @api states;
    @api countries;
    @api signerIndex;
    @track ssnPaddings = "padding-top:19px;";
    @track ssnIcon = "utility:preview";
    signerSectionCommonCSS = "slds-p-top_large slds-text-title_bold slds-text-heading_large textAlignCenter"; 

    handleDataChange(evt) {
        handleDataChange(this,evt,this.signerIndex);
    }
    validateAndRetrieve({ isSkipValidation } = { isSkipValidation: false }) {
        this.checkSSNFieldValidation();
        this.validateOwnerShipPercentage();
        return isValid(this);
    }
    @api
    isInputsValid() {
        this.checkSSNFieldValidation();
        return isValid(this);
    }
    get ssnType() {
        return this.ssnIcon === "utility:preview" ? "password" : "text";
    }
    get isSigner1() {
        return this.signerIndex === 0;
    }
    get currentSignerIndex() {
        return this.signerIndex + 1;
    }
    get signerSectionCSS() {
        return this.signerIndex === 0 ? this.signerSectionCommonCSS + ' width37' : this.signerSectionCommonCSS + ' width41';
    }
    validateOwnerShipPercentage() {
        const ownerPercent = this.template.querySelector('lightning-input[data-field="ownershipPercentage"]');

        if (ownerPercent) {
            if (ownerPercent.value === '' || ownerPercent.value === undefined) {
                ownerPercent.reportValidity();
                return;
            }
            let totalPercentage = 0;
            this.formData.signerInfo.forEach(item => {
                totalPercentage += parseInt(item.ownershipPercentage);
            }); 
            totalPercentage !== 100 ?
                ownerPercent.setCustomValidity(this.labels.errMustSumUpTo100Percent) :
                ownerPercent.setCustomValidity('');
            ownerPercent.reportValidity();
        } 
    }
    checkSSNFieldValidation() {
        let ssnField = this.template.querySelector('lightning-input[data-field="ssn"]');
        ssnField && (!ssnField.checkValidity()) ?  this.lowPadding() : this.highPadding();
    }
    handleSSNDynamicOperation(evt) {
        (evt.target.value === null || evt.target.value === '' || (evt.target.value).trim() === '') ?
            this.lowPadding() : this.template.querySelector('lightning-input[data-field="ssn"]').checkValidity() ?
                this.highPadding() : this.lowPadding();
        this.handleDataChange(evt);
    }
    highPadding() {
        this.ssnPaddings = "padding-top:19px;";
    }
    lowPadding() {
        this.ssnPaddings = "padding-top:6px;";
    }
    handleSSNAction(evt) {
        this.ssnIcon = evt.target.iconName === 'utility:preview' ? 'utility:hide' : 'utility:preview';
    }
    handleDOBChange(evt) {
        let ageInYears = (new Date().getTime() - new Date(evt.target.value).getTime()) / (1000 * 60 * 60 * 24 * 365);
        if (ageInYears < 18) {
            evt.currentTarget.setCustomValidity(this.labels.errMinimumAgeIs18Years);
            evt.currentTarget.reportValidity();
        } else {
            evt.currentTarget.setCustomValidity('');
            evt.currentTarget.reportValidity();
        }
        this.handleDataChange(evt);
    }
    handleDeleteSigner() {
        this.dispatchEvent(new CustomEvent('deletesigner', {
            detail: {
                signerIndex : this.signerIndex
        }}));
    }

}