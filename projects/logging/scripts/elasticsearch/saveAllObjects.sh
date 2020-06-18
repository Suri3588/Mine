#!/bin/bash

# This will attempt to save all kibana dashboards, visualizations and index patterns,
# to the current git branch.

$(dirname "$0")/listIndexPatterns.sh --ids-only | while read ID
do
	$(dirname "$0")/saveIndexPattern.sh --recurse "$ID"
done

$(dirname "$0")/listVisualizations.sh --ids-only | while read ID
do
	$(dirname "$0")/saveVisualization.sh --recurse "$ID"
done

$(dirname "$0")/listDashboards.sh --ids-only | while read ID
do
	$(dirname "$0")/saveDashboard.sh --recurse "$ID"
done

