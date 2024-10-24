import ACCOUNTING_SEED_HUB from '@salesforce/label/c.ACCOUNTING_SEED_HUB';
import accountingSeedHubAuth from '@salesforce/label/c.ACCOUNTING_SEED_HUB_AUTH';
import authorizeHubButton from '@salesforce/label/c.ACCOUNTING_SEED_HUB_AUTH_BUTTON';
import reauthorizeHubButton from '@salesforce/label/c.RE_ACCOUNTING_SEED_HUB_AUTH_BUTTON';
import accountingSeedHubAuthorizationError from '@salesforce/label/c.ERR_ACCOUNTING_SEED_HUB_AUTHORIZATION';
import accountingSeedHubAuthenticationError from '@salesforce/label/c.ERR_ACCOUNTING_SEED_HUB_AUTHENTICATION'; 
import errorLabel from '@salesforce/label/c.ERROR';

export const labels = () => {
    return {
        ACCOUNTING_SEED_HUB,
        accountingSeedHubAuth,
        authorizeHubButton,
        reauthorizeHubButton,
        accountingSeedHubAuthorizationError,
        accountingSeedHubAuthenticationError,
        errorLabel
    }
}