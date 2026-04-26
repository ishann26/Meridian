const express = require("express");
const router = express.Router();
const fetch = require("node-fetch");

router.post("/query", async (req, res) => {
  try {
    const { query } = req.body;

    if (!query) {
      return res.status(400).json({
        status: "error",
        message: "Query is required"
      });
    }

    // STEP 1: Call Route API
    const routeRes = await fetch("http://localhost:5000/route/compute", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        source: "Chennai",
        destination: "Mumbai"
      })
    });

    const routeData = await routeRes.json();

    // Dummy routes (until real routes come from teammate)
    const routes = [
      { id: "R1", cost: 5000, time: 10, risk: 0.7 },
      { id: "R2", cost: 7000, time: 8, risk: 0.3 }
    ];

    // STEP 2: Call Optimize API
    const optimizeRes = await fetch("http://localhost:5000/optimize/route", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        routes: routes
      })
    });

    const optimizeData = await optimizeRes.json();

    const bestRoute = optimizeData.data.best_route;

    // STEP 3: Generate response
    const explanation = `Best route is ${bestRoute} based on cost, risk, and time optimization.`;

    res.json({
      status: "success",
      data: {
        query,
        best_route: bestRoute,
        explanation
      },
      message: "Agent full pipeline working"
    });

  } catch (err) {
    res.status(500).json({
      status: "error",
      message: err.message
    });
  }
});

module.exports = router;