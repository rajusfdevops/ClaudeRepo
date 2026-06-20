public with sharing class AccountHealthCheckAction {

    public class Input {
        @InvocableVariable(required=true label='Account ID')
        public Id accountId;
    }

    public class Output {
        @InvocableVariable(label='Risk Level')
        public String riskLevel;

        @InvocableVariable(label='Risk Summary')
        public String riskSummary;

        @InvocableVariable(label='Recommended Action')
        public String recommendedAction;

        @InvocableVariable(label='Open Case Count')
        public Integer openCaseCount;

        @InvocableVariable(label='High Priority Case Count')
        public Integer highPriorityCaseCount;

        @InvocableVariable(label='Open Opportunity Count')
        public Integer openOpportunityCount;

        @InvocableVariable(label='Total Open Opportunity Value')
        public Decimal totalOpportunityValue;

        @InvocableVariable(label='Account Name')
        public String accountName;
    }

    @InvocableMethod(
        label='Account Health Check'
        description='Returns a risk verdict (Green / Amber / Red) for an Account by analysing open Cases and open Opportunities. Use this when the user asks for an account health check, risk assessment, or account status.'
        category='Account Management'
    )
    public static List<Output> checkHealth(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            results.add(evaluate(inp.accountId));
        }
        return results;
    }

    private static Output evaluate(Id accountId) {
        Output out = new Output();

        Account acc = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
        out.accountName = acc.Name;

        out.openCaseCount = [
            SELECT COUNT() FROM Case
            WHERE AccountId = :accountId AND IsClosed = false
        ];
        out.highPriorityCaseCount = [
            SELECT COUNT() FROM Case
            WHERE AccountId = :accountId AND IsClosed = false AND Priority = 'High'
        ];

        out.openOpportunityCount = [
            SELECT COUNT() FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
        ];
        List<AggregateResult> oppAgg = [
            SELECT SUM(Amount) totalAmount
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
        ];
        out.totalOpportunityValue = (Decimal) oppAgg[0].get('totalAmount');

        Boolean hasHighCases = out.highPriorityCaseCount != null && out.highPriorityCaseCount > 0;
        Boolean hasOpenCases = out.openCaseCount != null && out.openCaseCount > 0;
        Boolean hasOpenOpps  = out.openOpportunityCount != null && out.openOpportunityCount > 0;

        if (hasHighCases && !hasOpenOpps) {
            out.riskLevel         = '🔴 Red — High Risk';
            out.riskSummary       = out.accountName + ' is HIGH RISK — ' + out.highPriorityCaseCount
                + ' high-priority case(s) open with no active pipeline. Immediate attention required.';
            out.recommendedAction = 'Escalate to the Account Manager immediately and create a high-priority task to contact the customer within 24 hours. Would you like me to do that?';
        } else if (hasHighCases || (hasOpenCases && !hasOpenOpps)) {
            out.riskLevel         = '🟡 Amber — Needs Monitoring';
            out.riskSummary       = out.accountName + ' needs monitoring — ' + out.openCaseCount
                + ' open case(s)' + (hasOpenOpps
                    ? ' but ' + out.openOpportunityCount + ' open opportunity/ies worth $'
                        + formatAmount(out.totalOpportunityValue) + ' partially offset the risk.'
                    : ' with no active pipeline.');
            out.recommendedAction = 'Schedule a review call with the account team this week to address the open cases. Would you like me to create a follow-up task?';
        } else {
            out.riskLevel         = '🟢 Green — Healthy';
            out.riskSummary       = out.accountName + ' looks healthy — no open cases'
                + (hasOpenOpps
                    ? ' and ' + out.openOpportunityCount + ' open opportunity/ies worth $'
                        + formatAmount(out.totalOpportunityValue) + '.'
                    : '.');
            out.recommendedAction = 'Great time to propose an upsell or renewal conversation. Would you like me to find the right opportunity to update?';
        }

        return out;
    }

    private static String formatAmount(Decimal amount) {
        if (amount == null) return '0';
        return String.valueOf(amount.setScale(0));
    }
}
