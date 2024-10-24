import invalidXKey from '@salesforce/label/c.ERR_INVALID_XKEY_VALUE';
import receivePayment from '@salesforce/label/c.INF_RECEIVE_PAYMENT';
import infoCardxknoPaymentBankGlReadOnly from '@salesforce/label/c.INFO_CARDKNOX_PAYMENT_BANK_GL_READ_ONLY';
import convenienceFees from '@salesforce/label/c.CONVENIENCE_FEES';
import convenienceFeesHelp from '@salesforce/label/c.INF_CONVENIENCE_FEES_HELPTEXT';
import includeConvenienceFees from '@salesforce/label/c.INCLUDE_CONVENIENCE_FEES';
import includeConvenienceFeesHelp from '@salesforce/label/c.INF_INCLUDE_CONVENIENCE_FEES_HELPTEXT';
import totalPaymentAmount from '@salesforce/label/c.TOTAL_PAYMENT_AMOUNT';
import totalPaymentAmountHelp from '@salesforce/label/c.INF_TOTAL_PAYMENT_AMOUNT_HELPTEXT';
import conFeeGlAccount from '@salesforce/label/c.CON_FEE_GL_ACCOUNT';
import conFeeGlAccountHelp from '@salesforce/label/c.INF_CON_FEE_GL_ACCOUNT_HELPTEXT';
import requiredInfo from '@salesforce/label/c.INF_REQUIRED_WHEN_FEES_ARE_ENABLED';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    invalidXKey,
    receivePayment,
    infoCardxknoPaymentBankGlReadOnly,
    totalPaymentAmount,
    totalPaymentAmountHelp,
    includeConvenienceFeesHelp,
    includeConvenienceFees,
    convenienceFeesHelp,
    convenienceFees,
    conFeeGlAccount,
    conFeeGlAccountHelp,
    requiredInfo
}

export {labels}