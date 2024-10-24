import { api } from 'lwc';
import WizardItem from 'c/wizardItem';
import { handleDataChange,isValid } from "c/cardknoxDataChangeHelper";

export default class CardknoxStepAddressInfo extends WizardItem {
    @api formData;
    @api labels;
    @api states;
    @api countries;
    handleDataChange(evt) {
        handleDataChange(this,evt);
    }
    handleAddressSameCheckboxClick(evt) {
        this.dispatchEvent(new CustomEvent('addresssame', { detail: { checked: evt.target.checked } }));
        this.handleDataChange(evt);
    }
    validateAndRetrieve({isSkipValidation} = {isSkipValidation : false}) {
        return isValid(this);
    }
}