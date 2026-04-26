const express = require('express');
const router = express.Router();

router.post('/route', (req, res) => {
  try {
    const { routes, weights = {} } = req.body;

    if (!routes || !Array.isArray(routes) || routes.length === 0) {
      return res.status(400).json({ status: 'error', message: 'Invalid or missing routes array' });
    }

    const wCost = weights.cost !== undefined ? weights.cost : 1;
    const wRisk = weights.risk !== undefined ? weights.risk : 0.5;
    const wTime = weights.time !== undefined ? weights.time : 1;

    let bestRouteObj = null;
    let lowestScore = Infinity;

    for (const route of routes) {
      const time = route.time || 0;
      const score = (route.cost * wCost) + (route.risk * wRisk * 10000) + (time * wTime * 100);
      if (score < lowestScore) {
        lowestScore = score;
        bestRouteObj = route;
      }
    }

    let reason = 'Better overall score compared to other routes';
    if (routes.length === 1) {
      reason = 'Only available route';
    } else if (bestRouteObj) {
      let isLowestCost = true;
      let isLowestRisk = true;
      let isLowestTime = true;
      const bTime = bestRouteObj.time || 0;

      for (const route of routes) {
        if (route.id === bestRouteObj.id) continue;
        const rTime = route.time || 0;
        if (bestRouteObj.cost >= route.cost) isLowestCost = false;
        if (bestRouteObj.risk >= route.risk) isLowestRisk = false;
        if (bTime >= rTime) isLowestTime = false;
      }

      const factors = [];
      if (isLowestRisk) factors.push('Lower risk');
      if (isLowestCost) factors.push('Lower cost');
      if (isLowestTime) factors.push('Lower time');

      if (factors.length > 0) {
        reason = `${factors.join(', ')} and better overall score compared to other routes`;
      }
    }

    return res.json({
      status: 'success',
      data: {
        best_route: bestRouteObj.id,
        score: lowestScore,
        reason: reason
      },
      message: 'Optimization complete'
    });
  } catch (error) {
    return res.status(500).json({ status: 'error', message: error.message });
  }
});

module.exports = router;