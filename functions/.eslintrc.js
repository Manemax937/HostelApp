module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "quotes": ["error", "double"],
    "max-len": ["warn", {"code": 100}],
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
};
