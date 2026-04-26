const express = require("express");
const router = express.Router();

router.post("/disruption", (req, res) => {
  try {
    const { route_id } = req.body;

    if (!route_id) {
      return res.status(400).json({
        status: "error",
        message: "route_id is required"
      });
    }

    res.json({
      status: "success",
      data: {
        risk: null
      },
      message: "Prediction service working"
    });

  } catch (err) {
    res.status(500).json({
      status: "error",
      message: err.message
    });
  }
});

module.exports = router;