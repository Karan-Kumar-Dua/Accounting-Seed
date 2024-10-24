import PUBLISH_PAYMENT_PROPOSAL_MSG from '@salesforce/label/c.PUBLISH_PAYMENT_PROPOSAL_MSG';
import TO_PUBLISH_PAYMENT_PROPOSAL from '@salesforce/label/c.TO_PUBLISH_PAYMENT_PROPOSAL';
import PP_PUBLISH_JOB_START from '@salesforce/label/c.PP_PUBLISH_JOB_START';
import PP_PUBLISH_JOB_END from '@salesforce/label/c.PP_PUBLISH_JOB_END';
import PP_APPROVE_TO_PAY from '@salesforce/label/c.PP_APPROVE_TO_PAY';
import ERR_PP_NO_PAYMENT_PROPOSAL_LINES_TO_PAY from '@salesforce/label/c.ERR_PP_NO_PAYMENT_PROPOSAL_LINES_TO_PAY'

export const ppLables = () => {
    return {
        PUBLISH_PAYMENT_PROPOSAL_MSG,
        TO_PUBLISH_PAYMENT_PROPOSAL,
        PP_PUBLISH_JOB_START,
        PP_PUBLISH_JOB_END,
        PP_APPROVE_TO_PAY,
        ERR_PP_NO_PAYMENT_PROPOSAL_LINES_TO_PAY
    }
}