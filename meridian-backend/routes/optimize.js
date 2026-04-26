const express = require("express");
const router = express.Router();

router.post("/route", (req, res) => {
  try {
    const { routes } = req.body;

    if (!routes || !Array.isArray(routes)) {
      return res.status(400).json({
        status: "error",
        message: "routes array is required"
      });
    }

    res.json({
      status: "success",
      data: {
        best_route: null
      },
      message: "Optimization service working"
    });

  } catch (err) {
    res.status(500).json({
      status: "error",
      message: err.message
    });
  }
});

module.exports = router;