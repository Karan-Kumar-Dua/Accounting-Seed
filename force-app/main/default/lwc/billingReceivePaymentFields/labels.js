import convenienceFees from '@salesforce/label/c.CONVENIENCE_FEES';
import convenienceFeesHelp from '@salesforce/label/c.INF_CONVENIENCE_FEES_HELPTEXT';
import includeConvenienceFees from '@salesforce/label/c.INCLUDE_CONVENIENCE_FEES';
import includeConvenienceFeesHelp from '@salesforce/label/c.INF_INCLUDE_CONVENIENCE_FEES_HELPTEXT';
import totalPaymentAmount from '@salesforce/label/c.TOTAL_PAYMENT_AMOUNT';
import totalPaymentAmountHelp from '@salesforce/label/c.INF_TOTAL_PAYMENT_AMOUNT_HELPTEXT';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    totalPaymentAmount,
    totalPaymentAmountHelp,
    includeConvenienceFeesHelp,
    includeConvenienceFees,
    convenienceFeesHelp,
    convenienceFees
}

export {labels}