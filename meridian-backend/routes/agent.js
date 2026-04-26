const express = require("express");
const router = express.Router();

router.post("/query", (req, res) => {
  try {
    const { query } = req.body;

    if (!query) {
      return res.status(400).json({
        status: "error",
        message: "Query is required"
      });
    }

    res.json({
      status: "success",
      data: {
        response: `You asked: ${query}`
      },
      message: "Agent working"
    });

  } catch (err) {
    res.status(500).json({
      status: "error",
      message: err.message
    });
  }
});

module.exports = router;