#include <string>
#include <vector>

int add(int lhs, int rhs);

void reset();

bool is_valid(const std::string &name, int flags);

template <typename T, typename U>
T combine(const T &lhs, const U &rhs);

class Widget {
public:
  Widget(int value, const std::string &name);
  ~Widget();

  const std::vector<int> &values() const;
  auto scaled(double factor) -> std::vector<double>;
  bool operator==(const Widget &other) const;
};
