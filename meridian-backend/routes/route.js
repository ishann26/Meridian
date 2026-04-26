const express = require("express");
const router = express.Router();

router.post("/compute", (req, res) => {
  try {
    const { source, destination } = req.body;

    if (!source || !destination) {
      return res.status(400).json({
        status: "error",
        message: "Missing source or destination"
      });
    }

    res.json({
      status: "success",
      data: {
        route: null
      },
      message: "Route service working"
    });

  } catch (err) {
    res.status(500).json({
      status: "error",
      message: err.message
    });
  }
});

module.exports = router;