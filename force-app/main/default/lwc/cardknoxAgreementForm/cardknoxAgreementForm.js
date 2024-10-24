import WizardItem from 'c/wizardItem';
export default class CardknoxAgreementForm extends WizardItem {
    validateAndRetrieve({isSkipValidation} = {isSkipValidation : false}) {
        return true;
    }

    get fullUrl() {
        return '/apex/AcctSeed__CardknoxAgreementForm';
    }

    connectedCallback() {
        window.addEventListener("message", this.handleVFResponse.bind(this));
    }
 
    handleVFResponse(message) {
        let eventData = JSON.parse(message.data);
        if (eventData.source === 'vfpage' && eventData.error === '' && eventData.token !== '') {
            this.dispatchEvent(new CustomEvent('tokenreceived', {
                detail: {
                    token: eventData.token
                }
            }));
        }
    }
}