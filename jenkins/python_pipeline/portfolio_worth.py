import fire

def fire_output(value):
    return 'total_future_value {value}!'.format(value=value)

# Define the variables
initial_value = 20000  # Initial portfolio value in USD
monthly_contribution = 2000  # Monthly investment in USD
annual_return_rate = 0.07  # 7% annual return rate
years = 20  # Investment period in years

# Convert the annual return rate to a monthly rate
monthly_return_rate = annual_return_rate / 12

# Total number of months
n_months = years * 12

# Future value of monthly contributions (using future value of a series formula)
future_value_contributions = monthly_contribution * ((1 + monthly_return_rate)**n_months - 1) / monthly_return_rate

# Future value of the initial portfolio
future_value_initial = initial_value * (1 + monthly_return_rate)**n_months

# Total future portfolio value
total_future_value = future_value_initial + future_value_contributions
total_future_value
print(total_future_value)

if __name__ == '__main__':
  fire.Fire(total_future_value)