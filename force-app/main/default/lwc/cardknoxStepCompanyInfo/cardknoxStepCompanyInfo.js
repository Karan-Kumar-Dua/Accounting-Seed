import { api, track } from 'lwc';
import WizardItem from 'c/wizardItem';
import { tierLabels} from "./labels";
import { handleDataChange,isValid } from "c/cardknoxDataChangeHelper";
export default class CardknoxStepCompanyInfo extends WizardItem {
    @api formData;
    @track labels;
    options = [];
    tiersOptions = [
        { label: tierLabels.businessServiceLabel, value: '1977_business_services' },
        { label: tierLabels.electricalPartsLabel, value: '1977_electrical' },
        { label: tierLabels.hvacLabel, value: '1977_hvac' },
        { label: tierLabels.legalServiceLabel, value: '1977_legal_services' },
        { label: tierLabels.professionalServiceLabel, value: '1977_professional_services' },
        { label: tierLabels.softwareLabel, value: '1977_computer_software' },
        { label: tierLabels.otherLabel, value: '1977_1977_nondescript' }
    ];

    @api  
    set labelsVal(val) {
        this.labels = val;
        this.options = [
            { label: this.labels.soleProp, value: this.labels.soleProp },
            { label: this.labels.partnership, value: this.labels.partnership },
            { label: this.labels.corporation, value: this.labels.corporation },
            { label: this.labels.soleOwner, value: this.labels.soleOwner },
            { label: this.labels.llcNp, value: this.labels.llcNp },
        ];
    } get labelsVal() {
        return this.labels;
    }
    
    handleDataChange(evt) {
        handleDataChange(this,evt);
    }
    validateAndRetrieve({isSkipValidation} = {isSkipValidation : false}) {
        return isValid(this);
    }
}