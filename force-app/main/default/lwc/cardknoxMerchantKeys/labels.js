//cardknox
import merchantHeader from '@salesforce/label/c.CRDKNX_MERCHANT_KEYS_HEADER';
import keysHelpText from '@salesforce/label/c.CRDKNX_XKEY_IFIELDS_HELP_TEXT';
import xKey from '@salesforce/label/c.CRDKNX_XKEY';
import iFields from '@salesforce/label/c.CRDKNX_IFIELDS';
import haveAnAccount from '@salesforce/label/c.CRDKNX_DONT_HAVE_ACCOUNT';
import createAccount from '@salesforce/label/c.CRDKNX_CREATE_ACCOUNT';
import keysSuccess from '@salesforce/label/c.CRDNKX_MERCHANT_KEYS_SUCCESS';
import formSuccess from '@salesforce/label/c.CRDNKX_BOARDING_FORM_SUCCESS';
import formError from '@salesforce/label/c.CRDKNX_FORM_ERROR';
import hiddenValue from '@salesforce/label/c.CRDKNX_HIDDEN_VALUE';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    merchantHeader,
    keysHelpText,
    xKey,
    iFields,
    createAccount,
    haveAnAccount,
    keysSuccess,
    formSuccess,
    formError,
    hiddenValue
}
export {labels};