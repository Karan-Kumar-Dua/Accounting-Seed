import {LightningElement, track} from 'lwc';

export default class Wizard extends LightningElement {
    @track currentStep

    pathItems;

    goNext(childCallback) {
        const currentStepIndex = this.pathItems.findIndex(item => item.id === this.currentStep.id);
        const nextStep = this.pathItems[currentStepIndex + 1];

        const wizardStep = this.template.querySelectorAll('[data-wizard-step]');
        let isInputValid = true, wizardData = {};
        
        wizardStep && wizardStep.forEach(item => {
            const { isValid, data } = item.validateAndRetrieve();
            wizardData = data;
            isInputValid = !isValid ? isValid : isInputValid;
        });
        
        isInputValid && nextStep && (this.currentStep = {...this.currentStep, ...nextStep, ...wizardData}) &&
            childCallback && childCallback();
    }

    goBack(prevStep, childCallback) {
        if (!prevStep) {
            const currentStepIndex = this.pathItems.findIndex(item => item.id === this.currentStep.id);
            prevStep = currentStepIndex && this.pathItems[currentStepIndex - 1] || this.pathItems[currentStepIndex];
        }

        const wizardStep = this.template.querySelector('[data-wizard-step]');
        const {data} = wizardStep && wizardStep.validateAndRetrieve({isSkipValidation: true});

        prevStep && (this.currentStep = {...this.currentStep, ...prevStep, ...data}) &&
            childCallback && childCallback();
    }
}